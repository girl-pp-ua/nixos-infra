{ lib, ... }: {
  options = with lib; {
    cfg.secrets = {
      tailscale = {
        authKeyFile = mkOption { type = types.path; };
        expiry = mkOption { type = types.str; };
      };
    };
  };
}