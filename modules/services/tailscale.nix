{ config, lib, ... }:
let
  cfg = config.polaris.services.tailscale;
in
{
  options.polaris.services.tailscale = {
    enable = lib.mkEnableOption "tailscale" // {
      default = true;
    };
    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = config.polaris.hosts.${config.networking.hostName}.internal.tags or [
        "tag:nix-infra"
        "tag:server"
      ];
      defaultText = lib.literalExpression "config.polaris.hosts.\${config.networking.hostName}.internal.tags";
    };
  };
  config = lib.mkIf cfg.enable {
    services.tailscale =
      let
        commonFlags = [
          "--ssh"
          "--advertise-exit-node"
          "--accept-dns=false"
        ];
      in
      {
        enable = true;
        openFirewall = true;
        useRoutingFeatures = "server";
        disableTaildrop = true;
        extraSetFlags = commonFlags;
        extraUpFlags = commonFlags ++ [
          "--advertise-tags=${lib.concatStringsSep "," cfg.tags}"
        ];
        authKeyFile = config.sops.secrets."tailscale/authKey".path;
        authKeyParameters = {
          ephemeral = false;
          preauthorized = true;
        };
      };

    # make sure our tailnet addresses are only reachable through the tailnet/loopback
    networking.nftables.tables.tailnet-guard = {
      family = "inet";
      content = ''
        chain input {
          type filter hook input priority filter - 1; policy accept;
          iifname { "lo", "tailscale0" } accept
          ip daddr 100.64.0.0/10 drop
          ip6 daddr fd7a:115c:a1e0::/48 drop
        }
      '';
    };

    systemd.services.tailscaled.restartIfChanged = false; # just don't.
    # restartIfChanged = !polaris.services.tailscale.isTsDeploy;

    sops.secrets."tailscale/authKey" = {
      mode = "0400";
      owner = "root";
      group = "root";
    };
  };
}
