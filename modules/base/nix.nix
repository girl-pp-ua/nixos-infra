{ pkgs, ... }:
{
  nix = {
    package = pkgs.lixPackageSets.git.lix;
    # package = pkgs.lix;
    settings = {
      experimental-features = [
        # 2024-11-17
        # https://git.lix.systems/lix-project/lix/src/branch/main/src/libutil/experimental-features
        "auto-allocate-uids"
        "cgroups"
        "daemon-trust-override"
        # "fetch-closure"
        "flakes"
        "nix-command"
        # "no-url-literals"
        # "parse-toml-timestamps"
        "pipe-operator"
        "read-only-local-store"
        "repl-automation"
      ];
      system-features = [
        "uid-range"
      ];
      trusted-users = [
        "root"
        "@wheel"
        "builder"
      ];
      auto-allocate-uids = true;
      auto-optimise-store = true;
      # fsync-store-paths = true;
      keep-build-log = false;
      keep-derivations = false;
      keep-outputs = false;
      pure-eval = false;
      sandbox = true;
      use-cgroups = true;
      use-xdg-base-directories = true;
      builders-use-substitutes = true;
    };
    optimise.automatic = true;
    sshServe.protocol = "ssh-ng";
    channel.enable = false;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
      persistent = true;
      randomizedDelaySec = "1800";
    };
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "idle";
    daemonIOSchedPriority = 7;
  };
  nixpkgs = {
    config = {
      allowAliases = false;
      allowUnfree = true;
      # (suppress warning)
      allowDeprecatedx86_64Darwin = true;
    };
    flake = {
      setNixPath = true;
      setFlakeRegistry = true;
    };
  };

  # default is 100, so puts it at 1:10 weight with other tasks under contention
  systemd.services.nix-daemon.serviceConfig.CPUWeight = 10;
}
