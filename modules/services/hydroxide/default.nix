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
    services.hydroxide = {
      enable = true;
      authfile = config.sops.secrets."hydroxide/auth".path;
      carddav.enable = false; # requires proxy setup
    };
    sops.secrets."hydroxide/auth" = { };
  };
}
