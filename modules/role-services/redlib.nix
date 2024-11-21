{ pkgs, lib, ... }:
let
  redlibSubdomain = "redlib.girl.pp.ua";
  mkEnvRecursive = prefix: attr:
    builtins.foldl' (acc: oldKey:
      let
        value = attr.${oldKey};
        newKey = "${prefix}_${lib.toUpper oldKey}";
        newAttr =
          if builtins.isAttrs value then
            mkEnvRecursive newKey value
          else if builtins.isList value then
            { ${newKey} = builtins.concatStringsSep "+"
                (builtins.map (builtins.toString) value); }
          else if builtins.isBool value then
            { ${newKey} = if value then "on" else "off"; }
          else
            { ${newKey} = builtins.toString value; };
      in acc // newAttr
    ) {} (builtins.attrNames attr);
  mkRedlibEnv = mkEnvRecursive "REDLIB";
in rec {
  services.redlib = {
    enable = true;
    package = pkgs.redlib;
    address = "127.0.0.1";
    port = 16001;
  };

  systemd.services.redlib.environment = mkRedlibEnv {
    robots_disable_indexing = true;
    enable_rss = true;
    full_url = "https://${redlibSubdomain}/";
    default = {
      blur_spoiler = true;
      show_nsfw = true;
      blur_nsfw = true;
      use_hls = true;
      hide_hls_notification = true;
      disable_visit_reddit_confirmation = true;
    };
  };

  services.caddy.virtualHosts = {
    ${redlibSubdomain} = {
      extraConfig = ''
        reverse_proxy localhost:${builtins.toString services.redlib.port}
      '';
    };
  };
}