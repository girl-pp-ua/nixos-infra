{ lib, ... }:
{
  options = with lib; {
    cfg.secrets = {
      webdav = {
        username = mkOption { type = types.str; };
        hashed_password = mkOption { type = types.str; };
      };
      ociTenancy = {
        tenancyName = mkOption { type = types.str; };
        tenancyRegion = mkOption { type = types.str; };
        identityDomain = mkOption { type = types.str; };
      };
    };
  };
}
