{
  lib,
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

    exarch = {
      hostName = "81.2.102.158:444";
      systems = [ "x86_64-linux" ];
      supportedFeatures = [
        "kvm"
        "big-parallel"
        "nixos-test"
      ];
      # protocol = "ssh-ng";
      protocol = "ssh";
      sshUser = "luna";
      inherit sshKey;
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUxac0dCWjl5emRmSEJQSDlmcEZNcElUNStaeERrK0dkUWVMNG9YNkJ6UDcgcm9vdEBab3JheWFzCg==";
      maxJobs = 32;
      speedFactor = 30;
    };
  };
in
{
  nix = {
    distributedBuilds = true;
    buildMachines = builtins.attrValues machines;
  };

  sops.secrets = {
    "keys/builder" = {
      sopsFile = "${inputs.secrets}/keys/builder.sops";
      format = "binary";
      mode = "0400";
    }
    // lib.optionalAttrs (config ? users.users.hydra-queue-runner) {
      owner = "hydra-queue-runner";
      group = "hydra";
    };
  };

  # programs.ssh.knownHosts = {
  #   "[81.2.102.158]:444".publicKey =
  #     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILZsGBZ9yzdfHBPH9fpFMpIT5+ZxDk+GdQeL4oX6BzP7";
  # };
}
