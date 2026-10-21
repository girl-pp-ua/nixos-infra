{
  lib,
  pkgs,
  pkgs-stable,
  ...
}:
{
  nix = {
    # lixPackageSets.git is broken as of nixpkgs 09063bd
    package = pkgs.lixPackageSets.latest.lix;
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
    overlays = [
      (self: super: {
        inherit (pkgs-stable) caddy;
      })

      # CVE-2026-109618/CVE-2026-109619 (php2shell)
      (self: super: {
        php84 =
          if lib.versionOlder super.php84.version "8.4.27" then
            (super.php84.override {
              version = "8.4.27";
              hash = "sha256-slMKh3xyL0sIyeF0owywi6wrfhkD7m6eMV8KqfX4LCQ=";
            }).withExtensions
              (
                { enabled, ... }:
                # oom_filter_* tests fail in the sandbox
                map (
                  ext: if ext.extensionName == "filter" then ext.overrideAttrs { doCheck = false; } else ext
                ) enabled
              )
          else
            lib.warn "nixpkgs php84 is already ${super.php84.version} (>= 8.4.27)" super.php84;
      })
    ];
  };

  # default is 100, so puts it at 1:10 weight with other tasks under contention
  systemd.services.nix-daemon.serviceConfig.CPUWeight = 10;
}
