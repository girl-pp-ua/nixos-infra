{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = config.nix-infra.svc.redlib;
  mkEnvRecursive =
    prefix: attr:
    builtins.foldl' (
      acc: oldKey:
      let
        value = attr.${oldKey};
        newKey = "${prefix}_${lib.toUpper oldKey}";
        newAttr =
          if builtins.isAttrs value then
            mkEnvRecursive newKey value
          else if builtins.isList value then
            {
              ${newKey} = builtins.concatStringsSep "+" (builtins.map (builtins.toString) value);
            }
          else if builtins.isBool value then
            { ${newKey} = if value then "on" else "off"; }
          else
            { ${newKey} = builtins.toString value; };
      in
      acc // newAttr
    ) { } (builtins.attrNames attr);
  mkRedlibEnv = mkEnvRecursive "REDLIB";

  environment = mkRedlibEnv {
    robots_disable_indexing = true;
    enable_rss = true;
    full_url = "https://${cfg.domain}/";
    banner = ''
      <img src="/banner.webp" width="498" height="277" alt="mrrp,, :3">
      <div class="jrusbci8">Hosted on <a href="https://infra.beeg.pp.ua/">infra.beeg.pp.ua</a> :3</div>
      <span class="nyhis5pg" aria-hidden="true">INSTANCE_IS_HEALTHY</span>
      <style>
        .jrusbci8{text-align:center}
        .jrusbci8 a{text-decoration:underline}
        .nyhis5pg{display:none}
        body{background:linear-gradient(to right,rgba(0,0,0,.5),rgba(0,0,0,.9) 20%,rgba(0,0,0,.9) 25%,rgba(0,0,0,.9) 50%,rgba(0,0,0,.9) 75%,rgba(0,0,0,.9) 80%,rgba(0,0,0,.5)),linear-gradient(to bottom,#55cdfc,#b39de9,#f7a8b8,#f6d8dd,#fff 45%,#fff,#fff 55%,#f6d8dd,#f7a8b8,#b39de9,#55cdfc);background-attachment:fixed}
        @media(max-width:802px){body{background-image:linear-gradient(to right,rgba(0,0,0,.75),rgba(0,0,0,.75)),linear-gradient(to bottom,#55cdfc,#b39de9,#f7a8b8,#f6d8dd,#fff 45%,#fff,#fff 55%,#f6d8dd,#f7a8b8,#b39de9,#55cdfc)}}
      </style>
    '';
    default = {
      blur_spoiler = true;
      show_nsfw = true;
      blur_nsfw = true;
      use_hls = true;
      hide_hls_notification = true;
      disable_visit_reddit_confirmation = true;
    };
  };

  # Use latest unstable/master branch version
  redlib' = pkgs.redlib.overrideAttrs (prev: {
    version = "unstable";

    src = "${inputs.redlib}";
    cargoDeps = pkgs.rustPlatform.importCargoLock {
      lockFile = "${inputs.redlib}/Cargo.lock";
    };

    # Use full-resolution images for embeds
    # (also fixes nsfw post thumbnails)
    postPatch = prev.postPatch or "" + ''
      sed -i 's/{{ post\.thumbnail\.url }}/{{ post.media.url }}/g' templates/post.html
    '';

    # Rate-limit check requires internet access (should be fixed upstream)
    doCheck = false;
  });
in
{
  options.nix-infra.svc.redlib = {
    enable = lib.mkEnableOption "redlib";
    port = lib.mkOption {
      type = lib.types.int;
      default = 16001;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "redlib.girl.pp.ua";
    };
  };

  config = lib.mkIf cfg.enable {
    services.redlib = {
      enable = true;
      package = redlib';
      address = "127.0.0.1";
      inherit (cfg) port;
    };

    systemd.services.redlib = {
      inherit environment;
    };

    services.caddy.virtualHosts = {
      ${cfg.domain} = {
        extraConfig = ''
          import encode
          import norobot
          import waf
          handle /banner.webp {
            rewrite * /tenor.webp
            reverse_proxy https://files.girl.pp.ua {
              header_up Host {http.reverse_proxy.upstream.host}
            }
          }
          reverse_proxy localhost:${builtins.toString cfg.port}
        '';
      };
    };
  };
}
