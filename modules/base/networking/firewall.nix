{ ... }:
{
  networking.firewall = {
    enable = true; # enable firewall
    filterForward = true;
    logRefusedConnections = false;
    allowPing = true;
  };
  networking.nftables = {
    enable = true;
    flattenRulesetFile = true;
  };
}
