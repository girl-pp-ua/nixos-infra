{ lib, ... }:
{
  networking.firewall = {
    enable = true;
    backend = lib.mkForce "iptables"; # nftables doesn't work in nixos-containers
    checkReversePath = "loose";
  };
  networking.useDHCP = lib.mkForce true;
  networking.useHostResolvConf = lib.mkForce false; # https://github.com/NixOS/nixpkgs/issues/162686
  services.resolved.enable = true;
}
