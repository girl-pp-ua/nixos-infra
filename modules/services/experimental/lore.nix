{
  inputs,
  config,
  system,
  lib,
  ...
}:
let
  cfg = config.polaris.services.experimental.lore;
  pkgs-lore = import inputs.nixpkgs-lore {
    inherit system;
  };
in
{
  imports = [
    "${inputs.nixpkgs-lore}/nixos/modules/services/networking/loreserver.nix"
  ];
  options.polaris.services.experimental.lore = {
    enable = lib.mkEnableOption "lore";
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "lore.lunya.cc";
    };
  };
  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        inherit (pkgs-lore) lore;
      })
    ];

    services.loreserver = {
      enable = true;
      settings = {
        server.auth = rec {
          jwt_issuer = "https://${config.polaris.services.kanidm.domain}/oauth2/openid/${cfg.client_id}";
          jwt_audience = [ "lore" ];
          jwk.endpoint = "${jwt_issuer}/public_key.jwk";
        };
      };
    };
  };
}
