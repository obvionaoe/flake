{
  config,
  lib,
  pkgs,
  user,
  nur,
  ...
}: let
  cfg = config.modules.firefox;

  addons = pkgs.nur.repos.rycee.firefox-addons;

  defaultExtensions = with addons; [
    auto-tab-discard
    bitwarden
    clearurls
    disconnect
    duckduckgo-privacy-essentials
    facebook-container
    multi-account-containers
    octolinker
    open-in-freedium
    redirector
    refined-github
    ublock-origin
    unpaywall
  ];

  defaultSearch = {
    default = "Unduckified";
    engines = {
      "Home Manager Options" = {
        urls = [{template = "https://home-manager-options.extranix.com/?query={searchTerms}";}];
        definedAliases = ["@hm"];
      };
      "Nix Flakes" = {
        urls = [{template = "https://search.nixos.org/flakes?query={searchTerms}";}];
        definedAliases = ["@nf"];
      };
      "Nix Options" = {
        urls = [{template = "https://search.nixos.org/options?query={searchTerms}";}];
        definedAliases = ["@no"];
      };
      "Nix Packages" = {
        urls = [{template = "https://search.nixos.org/packages?query={searchTerms}";}];
        definedAliases = ["@np"];
      };
      "NixOS Wiki" = {
        urls = [{template = "https://wiki.nixos.org/index.php?search={searchTerms}";}];
        definedAliases = ["@nw"];
      };
      "Open VSX Registry" = {
        urls = [{template = "https://open-vsx.org/?search={searchTerms}";}];
        definedAliases = ["@vsx"];
      };
      "Unduckified" = {
        urls = [{template = "https://s.dunkirk.sh?q={searchTerms}";}];
      };

      "bing".metaData.hidden = true;
      "ddg".metaData.hidden = true;
      "google".metaData.hidden = true;
      "wikipedia".metaData.hidden = true;
    };
    force = true;
  };

  defaultSettings = {
    "browser.download.autohideButton" = true;
    "browser.startup.page" = 3;
    "browser.toolbars.bookmarks.visibility" = "newtab";
    "browser.urlbar.suggest.clipboard" = false;
    "browser.compactmode.show" = true;
    "browser.quitShortcut.disabled" = true;
    "browser.tabs.inTitlebar" = 1;
    "browser.tabs.insertAfterCurrent" = true;
    "browser.tabs.groups.enabled" = true;
    "browser.tabs.tabmanager.enabled" = false;
    "browser.uidensity" = 2;
    "clipboard.autocopy" = false;
    "extensions.autoDisableScopes" = 0;

    "middlemouse.paste" = false;
    "privacy.clearOnShutdown.cache" = false;
    "privacy.clearOnShutdown.cookies" = false;
    "privacy.clearOnShutdown.offlineApps" = false;
    "privacy.donottrackheader.enabled" = true;
    "privacy.globalprivacycontrol.enabled" = true;
    "privacy.globalprivacycontrol.was_ever_enabled" = true;
    "privacy.sanitize.sanitizeOnShutdown" = false;
    "svg.context-properties.content.enabled" = true;
  };
in {
  # Only a single "personal" profile is ported from the old flake — it had
  # near-empty "work"/"school" profiles too, which added no content of their
  # own beyond being separate identity containers; add more back trivially
  # via programs.firefox.profiles.<name> if you want them.
  options.modules.firefox.enable = lib.mkEnableOption "Firefox";

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [nur.overlays.default];

    home-manager.users.${user}.programs.firefox = {
      enable = true;
      package = pkgs.unstable.firefox;

      policies = {
        CaptivePortal = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DisableFirefoxAccounts = true;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        OfferToSaveLoginsDefault = false;
        PasswordManagerEnabled = false;
        FirefoxHome = {
          Highlights = false;
          Pocket = false;
          Search = false;
          Snippets = false;
          SponsoredPocket = false;
          SponsoredTopSites = false;
          TopSites = false;
        };
        UserMessaging = {
          ExtensionRecommendations = false;
          SkipOnboarding = true;
          MoreFromMozilla = false;
          FirefoxLabs = false;
        };
      };

      profiles.personal = {
        id = 0;
        name = "personal";
        isDefault = true;

        search = defaultSearch;
        settings =
          defaultSettings
          // {
            "dom.security.https_only_mode" = true;
          };

        extensions.packages =
          defaultExtensions
          ++ (with addons; [
            augmented-steam
            containerise
            darkreader
            dearrow
            modrinthify
            mullvad
            noscript
            protondb-for-steam
            remove-youtube-s-suggestions
            return-youtube-dislikes
            sponsorblock
            steam-database
            user-agent-string-switcher
            watchmarker-for-youtube
          ]);
      };
    };
  };
}
