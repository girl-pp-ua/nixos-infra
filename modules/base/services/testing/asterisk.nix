{ config, lib, ... }:
let cfg = config.cfg; in {
  options = {
    cfg.services.testing.asterisk = {
      enable = lib.mkEnableOption "asterisk phone system";
    };
  };
  config = lib.mkIf cfg.services.testing.asterisk.enable {
    services.asterisk = {
      enable = true;
      extraConfig = ''
        [options]
        verbose=10
        debug=10
      '';
      confFiles = {
        # "asterisk.conf" = ''
        #   [directories](!)
        #   astetcdir => /etc/asterisk
        #   astmoddir => /usr/lib/asterisk/modules
        #   astvarlibdir => /var/lib/asterisk
        #   astdbdir => /var/lib/asterisk
        #   astkeydir => /var/lib/asterisk
        #   astdatadir => /var/lib/asterisk
        #   astagidir => /var/lib/asterisk/agi-bin
        #   astspooldir => /var/spool/asterisk
        #   ; [options]
        #   ; astrundir => /var/run/asterisk
        #   ; astlogdir => /var/log/asterisk
        #   ; astsbindir => /usr/sbin
        #   ; runuser = asterisk ; The user to run as. The default is root.
        #   ; rungroup = asterisk ; The group to run as. The default is root
        # '';
        "modules.conf" = ''
          [modules]
          autoload=yes
          ; preload=res_odbc.so
          ; preload=res_config_odbc.so
          noload=chan_sip.so ; deprecated SIP module from days gone by
          noload=res_adsi.so
          noload=app_adsiprog.so
          noload=app_getcpeid.so
        '';
        "logger.conf" = ''
          [general]

          [logfiles]
          full => notice,warning,error ;,debug,verbose
          syslog.local0 => notice,warning,error ;,debug,verbose
        '';
        "pjsip.conf" = ''
          [global]

          [transport-udp]
          type=transport
          protocol=udp
          bind=0.0.0.0

          [transport-tcp]
          type=transport
          protocol=tls
          bind=0.0.0.0

          [apstest1-aors]
          type=aor
          max_contacts=1

          [apstest1-auth]
          type=auth
          auth_type=userpass
          username=apstest1
          password=thah8EeB
          realm=voip.girl.pp.ua

          [apstest1-endpoint]
          type=endpoint
          context=softphones
          disallow=all
          allow=g722
          allow=ulaw
          allow=alaw
          auth=apstest1-auth
          aors=apstest1-aors

          [apstest1-registration]
          type=registration
          transport=transport-udp
          outbound_auth=apstest1-auth
          server_uri=sip:voip.girl.pp.ua
          client_uri=sip:apstest@voip.girl.pp.ua
          contact_user=apstest1

          [apstest1-identify]
          type=identify
          endpoint=apstest1

          [apstest2-aors]
          type=aor
          max_contacts=1

          [apstest2-auth]
          type=auth
          auth_type=userpass
          username=apstest2
          password=ooQu1ohz0U
          realm=voip.girl.pp.ua

          [apstest2-endpoint]
          type=endpoint
          context=softphones
          disallow=all
          allow=g722
          allow=ulaw
          allow=alaw
          auth=apstest2-auth
          aors=apstest2-aors

          [apstest2-registration]
          type=registration
          transport=transport-udp
          outbound_auth=apstest2-auth
          server_uri=sip:voip.girl.pp.ua
          client_uri=sip:apstest@voip.girl.pp.ua
          contact_user=apstest2

          [apstest2-identify]
          type=identify
          endpoint=apstest2
        '';
        "iax.conf" = ''
          [general]
          context=unauthenticated
          allowguest=no
          srvlookup=no  ; Don't do DNS lookup
          udpbindaddr=0.0.0.0  ; Listen on all interfaces
          tcpenable=no
        '';
      };
    };
    networking.firewall = {
      # SIP
      allowedTCPPorts = [ 5060 ];
      allowedUDPPorts = [ 5060 ];
      # RTP
      allowedUDPPortRanges = [
        { from = 5000; to = 31000; }
      ];
    };
  };
}