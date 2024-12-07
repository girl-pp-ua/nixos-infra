{ config, lib, ... }:
let cfg = config.cfg; in {
  options = {
    cfg.services.oauth2_proxy = {
      enable = lib.mkEnableOption "oauth2_proxy" // {
        # if canidm is enabled, oauth2_proxy will be enabled by default
        default = cfg.services.kanidm.enable;
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = 4180;
      };
    };
  };

  config = lib.mkIf cfg.services.oauth2_proxy.enable {
    # TODO

    # services.oauth2_proxy = {
    #   enable = true;
    #   httpAddress = "http://127.0.0.1:${toString cfg.services.oauth2_proxy.port}";
    #   provider = "oidc";
    #   # TODO
    # };

    # systemd.services.oauth2-proxy.after = [
    #   "kanidm.service"
    # ];
  };
}