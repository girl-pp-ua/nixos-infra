{ config, lib, ... }:
let
  cfg = config.cfg;
in
{
  options = {
    cfg.services.testing.asterisk = {
      enable = lib.mkEnableOption "asterisk phone system";
      domain = lib.mkOption {
        type = lib.types.str;
        default = "voip.girl.pp.ua";
        description = "Domain name for the asterisk server";
      };
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
        "modules.conf" = ''
          [modules]
          autoload=yes
          noload=chan_sip.so ; deprecated SIP module from days gone by
          noload=res_adsi.so     ; fails to load
          noload=app_adsiprog.so ; fails to load
          noload=app_getcpeid.so ; fails to load
        '';
        "logger.conf" = ''
          [general]

          [logfiles]
          full => notice,warning,error ;,debug,verbose
          syslog.local0 => notice,warning,error ;,debug,verbose
        '';
        "extensions.conf" = ''
          [from-internal]
          exten = 100,1,Answer()
          same = n,Wait(1)
          same = n,Playback(hello-world)
          same = n,Hangup()
        '';
        "pjsip.conf" =
          let
            mkEndpoint =
              { username, password }:
              ''

                [${username}]
                type=endpoint
                context=from-internal
                disallow=all
                allow=ulaw
                auth=${username}
                aors=${username}
                direct_media=no

                [${username}]
                type=auth
                auth_type=userpass
                password=${password}
                username=${username}

                [${username}]
                type=aor
                max_contacts=1
              '';
          in
          ''
            [global]

            [transport-udp]
            type = transport
            protocol = udp
            bind = 0.0.0.0:5060
            local_net=127.0.0.0/8
            local_net=10.0.0.0/8
            external_media_address = ${cfg.services.testing.asterisk.domain}
            external_signaling_address = ${cfg.services.testing.asterisk.domain}

            ${mkEndpoint {
              username = "6001";
              password = "aec2Eenoh6";
            }}

            ${mkEndpoint {
              username = "6002";
              password = "wo9UawaD4u";
            }}
          '';
        # "iax.conf" = ''
        #   [general]
        #   context=unauthenticated
        #   allowguest=no
        #   srvlookup=no  ; Don't do DNS lookup
        #   udpbindaddr=0.0.0.0  ; Listen on all interfaces
        #   tcpenable=no
        # '';
      };
    };
    networking.firewall = {
      # SIP
      allowedTCPPorts = [ 5060 ];
      allowedUDPPorts = [ 5060 ];
      # RTP
      allowedUDPPortRanges = [
        {
          from = 5000;
          to = 31000;
        }
      ];
    };
  };
}
