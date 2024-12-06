{ config, lib, ... }:
let cfg = config.cfg; in {
  options = {
    cfg.services.kanidm = {
      enable = lib.mkEnableOption "kanidm";
    };
  };
  config = lib.mkIf cfg.services.kanidm.enable {
    # TODO
    # services.kanidm = {
    #   enableServer = true;
    #   tls_chain = "";
    #   tls_key = "";
    # };
  };
}