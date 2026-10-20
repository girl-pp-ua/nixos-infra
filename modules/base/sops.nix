{ config, inputs, ... }:
{
  sops = {
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    defaultSopsFile = builtins.path { path = "${inputs.secrets}/secrets.sops.yaml"; name = "secrets.sops.yaml"; };
    defaultSopsFormat = "yaml";
  };
}
