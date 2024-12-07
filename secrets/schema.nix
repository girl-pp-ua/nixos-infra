{ lib, ... }: {
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
    };
  };
}