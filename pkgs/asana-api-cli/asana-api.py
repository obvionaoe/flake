#!/usr/bin/env python3
"""asana-api with an OAuth login flow bolted on.

Replaces the upstream `asana-api` entry point (see default.nix). Adds an
`auth` command group:

    asana-api auth login [--manual] [--port N] [--scopes S]
    asana-api auth status | token | logout [--forget-client]

Every other invocation is handed straight to upstream's CLI, after exporting
a fresh $ASANA_ACCESS_TOKEN from the stored OAuth token (refreshed first if
it's within a minute of expiry). An explicit --access-token or an already-set
$ASANA_ACCESS_TOKEN always wins, so a personal access token still works.

Asana has no public OAuth client for CLIs, so `login` needs your own app from
https://app.asana.com/0/my-apps — its client ID/secret are taken from
$ASANA_CLIENT_ID/$ASANA_CLIENT_SECRET or prompted for once, and stored next to
the token: in the login Keychain on macOS (via /usr/bin/security, whose path
never changes, so a rebuild doesn't trigger a Keychain access prompt), or a
0600 file under $XDG_CONFIG_HOME/asana-api-cli elsewhere.
"""

import argparse
import base64
import getpass
import hashlib
import http.server
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from pathlib import Path

AUTHORIZE_URL = "https://app.asana.com/-/oauth_authorize"
TOKEN_URL = "https://app.asana.com/-/oauth_token"
REVOKE_URL = "https://app.asana.com/-/oauth_revoke"
OOB_REDIRECT = "urn:ietf:wg:oauth:2.0:oob"
DEFAULT_PORT = 8080
KEYCHAIN_SERVICE = "asana-api-cli"
REFRESH_MARGIN = 60  # seconds


class AuthError(Exception):
    pass


# --- storage ---------------------------------------------------------------


class KeychainStore:
    def get(self, key):
        r = subprocess.run(
            ["/usr/bin/security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", key, "-w"],
            capture_output=True,
            text=True,
        )
        return json.loads(r.stdout) if r.returncode == 0 else None

    def put(self, key, value):
        # Fed through `security -i` on stdin, hex-encoded, so the secret never
        # shows up in a process argument list.
        data = json.dumps(value).encode().hex()
        cmd = f"add-generic-password -U -s {KEYCHAIN_SERVICE} -a {key} -X {data}\n"
        r = subprocess.run(["/usr/bin/security", "-i"], input=cmd, capture_output=True, text=True)
        if r.returncode != 0 or r.stderr.strip():
            raise AuthError(f"couldn't write to the Keychain: {r.stderr.strip()}")

    def delete(self, key):
        subprocess.run(
            ["/usr/bin/security", "delete-generic-password", "-s", KEYCHAIN_SERVICE, "-a", key],
            capture_output=True,
        )


class FileStore:
    def __init__(self):
        base = os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config"
        self.dir = Path(base) / "asana-api-cli"

    def get(self, key):
        try:
            return json.loads((self.dir / f"{key}.json").read_text())
        except FileNotFoundError:
            return None

    def put(self, key, value):
        self.dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        path = self.dir / f"{key}.json"
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            json.dump(value, f)

    def delete(self, key):
        (self.dir / f"{key}.json").unlink(missing_ok=True)


STORE = KeychainStore() if sys.platform == "darwin" else FileStore()


# --- OAuth -----------------------------------------------------------------


def post_form(url, fields):
    req = urllib.request.Request(url, data=urllib.parse.urlencode(fields).encode(), method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        try:
            body = json.loads(body).get("error_description") or body
        except ValueError:
            pass
        raise AuthError(f"{url} returned HTTP {e.code}: {body}") from None
    except urllib.error.URLError as e:
        raise AuthError(f"couldn't reach {url}: {e.reason}") from None


def client_credentials(prompt=False, scopes=None):
    """Client ID/secret: env vars win, then the store, then (on login) a prompt."""
    client = STORE.get("client") or {}
    env_id, env_secret = os.environ.get("ASANA_CLIENT_ID"), os.environ.get("ASANA_CLIENT_SECRET")
    if env_id and env_secret:
        client.update(client_id=env_id, client_secret=env_secret)
    if not (client.get("client_id") and client.get("client_secret")):
        if not prompt:
            raise AuthError("no OAuth client configured — run `asana-api auth login`")
        print("Create an app at https://app.asana.com/0/my-apps (see `asana-api auth login --help`).", file=sys.stderr)
        client["client_id"] = input("Asana OAuth client ID: ").strip()
        client["client_secret"] = getpass.getpass("Asana OAuth client secret: ").strip()
    if scopes:
        client["scopes"] = scopes
    client.setdefault("scopes", "default")
    if prompt:
        STORE.put("client", client)
    return client


def save_token(resp, previous=None):
    token = {
        "access_token": resp["access_token"],
        # refresh responses don't always repeat the refresh token
        "refresh_token": resp.get("refresh_token") or (previous or {}).get("refresh_token"),
        "expires_at": int(time.time()) + int(resp.get("expires_in", 3600)),
        "user": resp.get("data") or (previous or {}).get("user"),
    }
    STORE.put("token", token)
    return token


def fresh_token():
    """The stored access token, refreshed if it's about to expire; None if not logged in."""
    token = STORE.get("token")
    if not token:
        return None
    if token["expires_at"] - REFRESH_MARGIN > time.time():
        return token
    if not token.get("refresh_token"):
        raise AuthError("stored token has expired — run `asana-api auth login`")
    client = client_credentials()
    try:
        resp = post_form(
            TOKEN_URL,
            {
                "grant_type": "refresh_token",
                "client_id": client["client_id"],
                "client_secret": client["client_secret"],
                "refresh_token": token["refresh_token"],
            },
        )
    except AuthError as e:
        raise AuthError(f"token refresh failed ({e}) — run `asana-api auth login`") from None
    return save_token(resp, previous=token)


def wait_for_callback(port, state):
    """Serve exactly one request on the loopback redirect URI; return its auth code."""
    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            url = urllib.parse.urlsplit(self.path)
            if url.path != "/callback":
                self.send_error(404)
                return
            q = dict(urllib.parse.parse_qsl(url.query))
            result.update(q)
            ok = q.get("state") == state and "code" in q
            self.send_response(200 if ok else 400)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            msg = "Logged in — you can close this tab." if ok else "Login failed — check the terminal."
            self.wfile.write(msg.encode())

        def log_message(self, *args):
            pass

    class Server(http.server.HTTPServer):
        timed_out = False

        def handle_timeout(self):
            self.timed_out = True

    try:
        server = Server(("127.0.0.1", port), Handler)
    except OSError as e:
        raise AuthError(f"can't listen on port {port} ({e.strerror}) — pass --port, or use --manual") from None
    server.timeout = 300
    with server:
        # keep serving through stray requests (e.g. /favicon.ico) until the
        # callback itself arrives
        while not result:
            server.handle_request()
            if server.timed_out:
                raise AuthError("timed out waiting for the browser redirect")
    if "error" in result:
        raise AuthError(f"authorization denied: {result.get('error_description') or result['error']}")
    if result.get("state") != state:
        raise AuthError("state mismatch on the OAuth redirect — aborting")
    return result["code"]


def login(args):
    client = client_credentials(prompt=True, scopes=args.scopes)
    redirect_uri = OOB_REDIRECT if args.manual else f"http://localhost:{args.port}/callback"
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(24)
    url = AUTHORIZE_URL + "?" + urllib.parse.urlencode(
        {
            "client_id": client["client_id"],
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "state": state,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
            "scope": client["scopes"],
        }
    )

    print(f"Opening your browser to authorize asana-api:\n  {url}", file=sys.stderr)
    webbrowser.open(url)
    if args.manual:
        code = input("Paste the code Asana shows you: ").strip()
    else:
        print(
            f"Waiting for the redirect to {redirect_uri} ...\n"
            "(If Asana says the redirect_uri doesn't match: register exactly that URL on\n"
            "the app, or — for a command-line type app — Ctrl-C and rerun with --manual.)",
            file=sys.stderr,
        )
        code = wait_for_callback(args.port, state)

    resp = post_form(
        TOKEN_URL,
        {
            "grant_type": "authorization_code",
            "client_id": client["client_id"],
            "client_secret": client["client_secret"],
            "redirect_uri": redirect_uri,
            "code": code,
            "code_verifier": verifier,
        },
    )
    user = save_token(resp)["user"] or {}
    print(f"Logged in as {user.get('name', '?')} <{user.get('email', '?')}>.", file=sys.stderr)


def status(_args):
    token = STORE.get("token")
    if not token:
        print("Not logged in.")
        sys.exit(1)
    user = token.get("user") or {}
    left = int(token["expires_at"] - time.time())
    when = f"expires in {left // 60} min" if left > 0 else "expired (refreshed on next use)"
    print(f"Logged in as {user.get('name', '?')} <{user.get('email', '?')}>; access token {when}.")


def print_token(_args):
    token = fresh_token()
    if not token:
        raise AuthError("not logged in — run `asana-api auth login`")
    print(token["access_token"])


def logout(args):
    token, client = STORE.get("token"), STORE.get("client")
    if token and client and token.get("refresh_token"):
        try:  # best effort: revoking the refresh token also kills its access tokens
            post_form(
                REVOKE_URL,
                {
                    "client_id": client["client_id"],
                    "client_secret": client["client_secret"],
                    "token": token["refresh_token"],
                },
            )
        except AuthError as e:
            print(f"warning: couldn't revoke the token server-side: {e}", file=sys.stderr)
    STORE.delete("token")
    if args.forget_client:
        STORE.delete("client")
    print("Logged out.", file=sys.stderr)


def auth_main(argv):
    p = argparse.ArgumentParser(prog="asana-api auth", description="Manage the stored Asana OAuth login.")
    sub = p.add_subparsers(dest="cmd", required=True)

    lp = sub.add_parser(
        "login",
        help="log in through the browser (OAuth)",
        description=(
            "Needs an Asana OAuth app (https://app.asana.com/0/my-apps) with "
            f"http://localhost:{DEFAULT_PORT}/callback (or your --port) registered as a "
            f"redirect URL, or {OOB_REDIRECT} for --manual. Its client ID/secret come "
            "from $ASANA_CLIENT_ID/$ASANA_CLIENT_SECRET or are prompted for once."
        ),
    )
    lp.add_argument("--manual", action="store_true", help="paste the code yourself instead of a localhost redirect")
    lp.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("ASANA_OAUTH_REDIRECT_PORT", DEFAULT_PORT)),
        help=f"loopback redirect port (default: $ASANA_OAUTH_REDIRECT_PORT or {DEFAULT_PORT})",
    )
    lp.add_argument("--scopes", help='space-separated OAuth scopes (default: remembered value, else "default")')
    lp.set_defaults(fn=login)

    sub.add_parser("status", help="show who's logged in").set_defaults(fn=status)
    sub.add_parser("token", help="print a fresh access token").set_defaults(fn=print_token)

    op = sub.add_parser("logout", help="revoke and delete the stored token")
    op.add_argument("--forget-client", action="store_true", help="also delete the stored client ID/secret")
    op.set_defaults(fn=logout)

    args = p.parse_args(argv)
    args.fn(args)


def main():
    argv = sys.argv[1:]
    try:
        if argv[:1] == ["auth"]:
            return auth_main(argv[1:])
        explicit = os.environ.get("ASANA_ACCESS_TOKEN") or any(
            a == "--access-token" or a.startswith("--access-token=") for a in argv
        )
        offline = any(a in ("-h", "--help", "--version") for a in argv)
        if not explicit and not offline:
            token = fresh_token()
            if token:
                os.environ["ASANA_ACCESS_TOKEN"] = token["access_token"]
    except AuthError as e:
        sys.exit(f"asana-api: {e}")
    except KeyboardInterrupt:
        sys.exit(130)

    from asana_api_cli.cli import main as upstream_main

    upstream_main()


if __name__ == "__main__":
    main()
