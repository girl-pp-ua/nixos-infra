{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.polaris.services.experimental.svn;
in
{
  options.polaris.services.experimental.svn = {
    enable = lib.mkEnableOption "snvserve";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "svn.lunya.cc";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.services.svnserve = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      script = "${pkgs.subversion.out}/bin/svnserve -r /var/lib/svn -d --foreground";
      serviceConfig = {
        User = "svn";
        Group = "svn";
        StateDirectory = "svn";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
      };
    };

    users.users.svn = {
      isSystemUser = true;
      group = "svn";
    };
    users.groups.svn = { };

    networking.firewall.allowedTCPPorts = [
      3690
    ];

    environment.systemPackages = with pkgs; [
      subversion
      subversionClient
    ];
  };
}
