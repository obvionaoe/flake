{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.kubernetes;

  # ~150 short aliases, unchanged from the old flake. Deliberately not
  # retyped or "cleaned up" — this is a large, already-battle-tested muscle
  # -memory alias set, and the value here is fidelity to the original.
  #
  # The old flake's `ky*` aliases ("k neat get X") are dropped along with the
  # kubectl-neat package below (stale ~1.5yr, no successor) — see the package
  # audit artifact. They weren't repointed to `k get X -o yaml` because that's
  # not equivalent: neat specifically strips managed noise (resourceVersion,
  # uid, creationTimestamp, status, etc.) that plain -o yaml keeps.
  coreAliases = {
    k = "kubecolor";
    kcwd = ''export KUBECONFIG="$PWD/kubeconfig"'';

    ktp = "k top pods";
    ktn = "k top nodes";

    kg = "k get";
    kd = "k describe";
    ke = "k edit";
    kdel = "k delete";
    kdelf = "k delete -f";
    kaf = "k apply -f";
    keti = "k exec -t -i";

    kge = "kg events";

    kgp = "kg pods";
    kgpl = "kgp -l";
    kgpn = "kgp -n";
    kgpsl = "kgp --show-labels";
    kgpall = "kgp --all-namespaces";
    kgpw = "kgp --watch";
    kgpwide = "kgp -o wide";
    kep = "ke pods";
    kdp = "kd pods";
    kdelp = "kdel pods";
    kgpallwide = "kgpall -o wide";

    kgs = "kg svc";
    kgsall = "kgs --all-namespaces";
    kgsw = "kgs --watch";
    kgswide = "kgs -o wide";
    kes = "ke svc";
    kds = "kd svc";
    kdels = "kdel svc";
    kgsallwide = "kgsall -o wide";

    kgi = "kg ingress";
    kgiall = "kgi --all-namespaces";
    kei = "ke ingress";
    kdi = "kd ingress";
    kdeli = "kdel ingress";

    kgns = "kg ns";
    kens = "ke ns";
    kdns = "kd ns";
    kdelns = "kdel ns";

    kgcm = "kg cm";
    kgcmall = "kgcm --all-namespaces";
    kecm = "ke cm";
    kdcm = "kd cm";
    kdelcm = "kdel cm";

    kgsec = "kg secret";
    kgsecall = "kgsec --all-namespaces";
    kdsec = "kd secret";
    kdelsec = "kdel secret";
    kgsecd = ''_kgsecd(){kgsec $1 -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'}; _kgsecd'';

    kgd = "kg deployment";
    kgdall = "kgd --all-namespaces";
    kgdw = "kgd --watch";
    kgdwide = "kgd -o wide";
    ked = "ke deployment";
    kdd = "kd deployment";
    kdeld = "kdel deployment";
    ksd = "k scale deployment";
    krsd = "k rollout status deployment";

    kgrs = "kg replicaset";
    kdrs = "kd replicaset";
    kers = "ke replicaset";
    krh = "k rollout history";
    kru = "k rollout undo";

    kgsts = "kg sts";
    kgstsall = "kgsts --all-namespaces";
    kgstsw = "kgsts --watch";
    kgstswide = "kgsts -o wide";
    kests = "ke sts";
    kdsts = "kd sts";
    kdelsts = "kdel sts";
    kssts = "k scale sts";
    krssts = "k rollout status sts";

    kpf = "k port-forward";

    kga = "kg all";
    kgaall = "kg all --all-namespaces";

    kl = "k logs";
    kl1h = "kl --since 1h";
    kl1m = "kl --since 1m";
    kl1s = "kl --since 1s";
    klf = "kl -f";
    klf1h = "kl --since 1h -f";
    klf1m = "kl --since 1m -f";
    klf1s = "kl --since 1s -f";

    kcp = "k cp";

    kgno = "kg nodes";
    kgnosl = "kgno --show-labels";
    keno = "ke node";
    kdno = "kd node";
    kdelno = "kdel node";

    kgpvc = "kg pvc";
    kgpvcall = "kgpvc --all-namespaces";
    kgpvcw = "kgpvc --watch";
    kepvc = "ke pvc";
    kdpvc = "kd pvc";
    kdelpvc = "kdel pvc";

    kgpv = "kg pv";
    kgpvall = "kgpv --all-namespaces";
    kgpvw = "kgpv --watch";
    kepv = "ke pv";
    kdpv = "kd pv";
    kdelpv = "kdel pv";

    kgsa = "kg sa";
    kdsa = "kd sa";
    kdelsa = "kdel sa";

    kgds = "kg daemonset";
    kgdsall = "kgds --all-namespaces";
    kgdsw = "kgds --watch";
    keds = "ke daemonset";
    kdds = "kd daemonset";
    kdelds = "kdel daemonset";

    kgcj = "kg cronjob";
    kecj = "ke cronjob";
    kdcj = "kd cronjob";
    kdelcj = "kdel cronjob";

    kgj = "kg job";
    kej = "ke job";
    kdj = "kd job";
    kdelj = "kdel job";

    kctx = "kubectx";
    kctxc = "kubectx --current";
    kctxu = "kubectx --unset";
    kctxdel = "kubectx -d";

    kns = "kubens";
    knsc = "kubens --current";

    h = "helm";
  };
in {
  options.modules.kubernetes = {
    enable = lib.mkEnableOption "kubernetes toolchain (kubectl, kubectx/kubens, helm)";
    linting.enable = lib.mkEnableOption "k8s manifest linters (kubeconform, kube-linter, kube-score)";
    extras.enable = lib.mkEnableOption "niche k8s tools (velero, pluto, operator-sdk, kubent, kube-capacity, kubectl-klock/ktop)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home-manager.users.${user} = {
        home.packages = with pkgs; [
          kubecolor
          kubectl
          kubernetes-helm
          kubectx
          kubecm
          kubeprompt
          kubeswitch
        ];

        home.shellAliases = coreAliases;
      };
    })

    (lib.mkIf (cfg.enable && cfg.linting.enable) {
      # trivy also covers Kubernetes manifests under `trivy config` (same
      # format-agnostic IaC scanner used by modules.terraform.linting) —
      # default-enabled here rather than installed a second time, and
      # folded straight into kchk alongside the other three checks.
      modules.trivy.enable = lib.mkDefault true;

      home-manager.users.${user} = {
        home.packages = with pkgs; [kubeconform kube-linter kube-score];

        home.shellAliases = {
          kconform = "kubeconform";
          klint = "kube-linter lint";
          kscore = "kube-score";
          kchk = "kconform . && klint . && kscore . && trivy config .";
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.extras.enable) {
      home-manager.users.${user} = {
        home.packages = with pkgs; [
          kube-capacity
          kubent
          kubectl-klock
          kubectl-ktop
          unstable.operator-sdk
          unstable.pluto
          unstable.velero
        ];

        home.shellAliases = {
          kcap = "kube-capacity";
          knt = "kubent";
          kwp = "kubecolor klock pods";
          ktop = "kubectl ktop";
        };
      };
    })
  ];
}
