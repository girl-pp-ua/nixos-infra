{ lib, ... }:
{
  imports = [
    ./agent.nix
    ./server.nix
  ];

  options.polaris.services.monitoring.exports = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          port = lib.mkOption { type = lib.types.port; };
          path = lib.mkOption {
            type = lib.types.str;
            default = "/metrics";
          };
          bearerTokenSecret = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      }
    );
    default = { };
  };
}
