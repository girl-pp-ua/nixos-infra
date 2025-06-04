{ lib, ... }:
{
  options = with lib; {
    cfg.secrets = {
      selfSignedCert = {
        tls_key = mkOption { type = types.path; };
        tls_chain = mkOption { type = types.path; };
      };
      tailscale = {
        authKeyFile = mkOption { type = types.path; };
        expiry = mkOption { type = types.str; };
      };
      oauth2_proxy = {
        cookieSecret = mkOption { type = types.str; };
      };
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
