{
  config,
  lib,
  ...
}:
{
  imports = [ ./module.nix ];

  options.cfg.services.hydroxide = {
    enable = lib.mkEnableOption "hydroxide service";
  };

  config = lib.mkIf config.cfg.services.hydroxide.enable {
    services.hydroxide =
      let
        host = "100.64.0.2";
      in
      {
        enable = true;
        debug = true;
        authfile = config.sops.secrets."hydroxide/auth".path;
        carddav.enable = false; # requires proxy setup
        imap = {
          inherit host;
          port = 1143;
        };
        smtp = {
          inherit host;
          port = 1025;
        };
      };
    sops.secrets."hydroxide/auth" = { };
  };
}
