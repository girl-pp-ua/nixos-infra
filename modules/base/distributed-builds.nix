{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  sshKey = config.sops.secrets."keys/builder".path;

  machines = {
    astra = {
      hostName = "astra.polaris";
      systems = [ "aarch64-linux" ];
      supportedFeatures = [
        "kvm"
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
  builderPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJz3xo+K9lHHXuR5rLWhwxok1/CP9KBFs7GEdEIYFl9t";
  isBuildMachine = machines ? ${config.networking.hostName};
  dispatchesBuilds = config.services.hydra.enable;
in
{
  config = lib.mkMerge [
    (lib.mkIf dispatchesBuilds {
      nix = {
        distributedBuilds = true;
        buildMachines = builtins.attrValues machines;
      };

      sops.secrets."keys/builder" = {
        sopsFile = builtins.path {
          path = "${inputs.secrets}/keys/builder.sops";
          name = "builder.sops";
        };
        format = "binary";
        mode = "0400";
        owner = "hydra-queue-runner";
        group = "hydra";
      };
    })

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
