{
  config,
  pkgs,
  pkgs-stable,
  ...
}:
{
  nix = {
    package = pkgs.nixVersions.git;
    settings = {
      experimental-features = [
        # `nix __dump-xp-features`
        "auto-allocate-uids"
        "cgroups"
        # "fetch-closure"
        "flakes"
        "nix-command"
        # "parse-toml-timestamps"
        "pipe-operators"
        "read-only-local-store"
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
      # pull token for the private attic cache
      netrc-file = config.security.nix-secrets.secrets."attic/netrc".path;
      extra-substituters = [
        "https://nixpkgs-update-cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://nix-secrets.cachix.org"
        "https://cache.lunya.cc/main"
      ];
      extra-trusted-substituters = [
        "https://cache.flakehub.com"
      ];
      extra-trusted-public-keys = [
        "nixpkgs-update-cache.nixos.org-1:U8d6wiQecHUPJFSqHN9GSSmNkmdiFW7GW7WNAnHW0SM="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nix-secrets.cachix.org-1:NSwybk1LexO4kPH755itLM1t2NGegVq9YR22KlG8Vp0="
        "cache.lunya.cc-main:yJSPsDsyHG+MCBJ4KwHpMVheme11WjGH4p12HoJKOd8="
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
        "cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio="
        "cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU="
        "cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU="
        "cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8="
        "cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ="
        "cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o="
        "cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y="
      ];
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
    ];
  };

  security.nix-secrets.secrets."attic/netrc".generator.attic-token = {
    sub = "nix-hosts";
    pull = [ "main" ];
  };

  # default is 100, so puts it at 1:10 weight with other tasks under contention
  systemd.services.nix-daemon.serviceConfig.CPUWeight = 10;
}
