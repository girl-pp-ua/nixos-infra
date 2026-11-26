{
  lib,
  pkgs,
  config,
  ...
}:
let
  sshKey = config.security.nix-secrets.secrets."keys/builder".path;

  machines = {
    astra = {
      hostName = "astra.polaris";
      systems = [ "aarch64-linux" ];
      supportedFeatures = [
        "big-parallel"
        "nixos-test"
      ];
      # protocol = "ssh-ng";
      protocol = "ssh";
      sshUser = "builder";
      inherit sshKey;
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSURXbmpNODhiTTBIRmVLWkw3QUFBdUczeW40c21IaXFZcXhxN2FTTURYTG8gcm9vdEBpbnN0YW5jZS0yMDI2MDQwNy0xNzQyCg==";
      maxJobs = 8;
      speedFactor = 10;
    };

    amoeba = {
      hostName = "amoeba.polaris";
      systems = [ "x86_64-linux" ];
      supportedFeatures = [
        # amoeba has no kvm support. womp womp.
        "big-parallel"
        "nixos-test"
      ];
      # protocol = "ssh-ng";
      protocol = "ssh";
      sshUser = "builder";
      inherit sshKey;
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU9MT2dhQnJsS0ZQRDk5OWg0TWtUaTFYMkszcU4wVUt0M2M4NDFKbDBLMjAgcm9vdEBhbW9lYmEK";
      maxJobs = 8;
      speedFactor = 20;
    };

    dell-sv = {
      hostName = "dell-sv.polaris";
      systems = [ "x86_64-linux" ];
      supportedFeatures = [
        "kvm"
        "big-parallel"
        "nixos-test"
      ];
      # protocol = "ssh-ng";
      protocol = "ssh";
      sshUser = "builder";
      inherit sshKey;
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUJWdU1yenBPeHdqV3ZFMGp5b0xVSjBudTZpbmgxOS9rb1ptUFlHMC8zbzcgcm9vdEBkZWxsLXBjCg==";
      maxJobs = 4;
      speedFactor = 10;
    };

    # exarch = {
    #   hostName = "81.2.102.158:444";
    #   systems = [ "x86_64-linux" ];
    #   supportedFeatures = [
    #     "kvm"
    #     "big-parallel"
    #     "nixos-test"
    #   ];
    #   # protocol = "ssh-ng";
    #   protocol = "ssh";
    #   sshUser = "luna";
    #   inherit sshKey;
    #   publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUxac0dCWjl5emRmSEJQSDlmcEZNcElUNStaeERrK0dkUWVMNG9YNkJ6UDcgcm9vdEBab3JheWFzCg==";
    #   maxJobs = 8;
    #   speedFactor = 30;
    # };
  };
  builderPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4nyexgv9f/uqBnD1tVzyhZ237AxtLxWv4h4dyxtOLW";
  isBuildMachine = machines ? ${config.networking.hostName};
in
{
  # hydra builders dial in over grpc now (services/hydra.nix); this is for ad hoc ssh builds
  config = lib.mkMerge [
    (lib.mkIf isBuildMachine {
      users.users.builder = {
        isNormalUser = true;
        home = "/home/builder";
        createHome = true;
        hashedPassword = "!";
        shell = pkgs.bashInteractive;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB23Z5khaSPYhYX1AZFZIVKwjXaDZbGQFVxzPPWa6f4r user@fw13"
          ''restrict,command="${config.nix.package}/bin/nix-store --serve --write" ${builderPubkey}''
        ];
      };
      nix.settings.trusted-users = [ "builder" ];
    })
  ];
}
