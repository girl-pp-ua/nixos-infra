{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.forgejo;
  idp = libx.idp {
    domain = config.polaris.services.kanidm.domain;
    inherit (cfg) client_id;
  };
  catppuccin-gitea = pkgs.fetchzip {
    url = "https://github.com/griffi-gh/catppuccin-gitea/releases/download/v1.0.1/catppuccin-gitea.tar.gz";
    hash = "sha256-fpQM3ghvMOuzP6B9p0b0ogjkk6/KZVOc/5e65JJVSso=";
    stripRoot = false;
  };
in
{
  options.polaris.services.forgejo = {
    enable = lib.mkEnableOption "forgejo";
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "forgejo.polaris";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "git.lunya.cc";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "forgejo";
    };
  };

  config = lib.mkIf cfg.enable {
    services.forgejo = {
      enable = true;
      package = pkgs.forgejo;
      lfs.enable = true;
      dump.enable = true;
      database = {
        type = "postgres";
        createDatabase = true;
      };
      useWizard = false;
      secrets = {
        security.SECRET_KEY = lib.mkForce config.sops.secrets."forgejo/secret_key".path;
        security.INTERNAL_TOKEN = lib.mkForce config.sops.secrets."forgejo/internal_token".path;
        oauth2.JWT_SECRET = lib.mkForce config.sops.secrets."forgejo/jwt_secret".path;
        server.LFS_JWT_SECRET = lib.mkForce config.sops.secrets."forgejo/lfs_jwt_secret".path;
      };
      settings = {
        server = {
          ROOT_URL = "https://${cfg.domain}/";
          DOMAIN = cfg.domain;
          PROTOCOL = "http+unix";
          DISABLE_SSH = true; # SSH_PORT = 2222; TODO
          OFFLINE_MODE = false;
          ENABLE_GZIP = true;
          LANDING_PAGE = "explore";
        };
        security = {
          INSTALL_LOCK = true;
          PASSWORD_HASH_ALGO = "argon2";
          CSRF_COOKIE_HTTP_ONLY = true;
          DISABLE_QUERY_AUTH_TOKEN = true;
        };
        service = {
          DISABLE_REGISTRATION = false;
          SHOW_REGISTRATION_BUTTON = false;
          ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
          ENABLE_INTERNAL_SIGNIN = false;
          ENABLE_BASIC_AUTHENTICATION = false;
        };
        session = {
          DOMAIN = cfg.domain;
          COOKIE_SECURE = true;
        };
        openid = {
          ENABLE_OPENID_SIGNIN = false;
          ENABLE_OPENID_SIGNUP = false;
          WHITELISTED_URIS = config.polaris.services.kanidm.domain;
        };
        oauth2_client = {
          OPENID_CONNECT_SCOPES = "profile email groups";
          ENABLE_AUTO_REGISTRATION = true;
          ACCOUNT_LINKING = "login";
          USERNAME = "nickname"; # preferred_username?
          UPDATE_AVATAR = true;
        };
        picture = {
          DISABLE_GRAVATAR = false;
          GRAVATAR_SOURCE = "gravatar";
          ENABLE_FEDERATED_AVATAR = true;
        };
        repository = {
          DEFAULT_BRANCH = "master"; # sorry im too used to this one :p
        };
        indexer = {
          REPO_INDEXER_ENABLED = true;
          REPO_INDEXER_FUZZY_ENABLED = true;
        };
        ui = {
          DEFAULT_THEME = "catppuccin-pink-auto";
          THEMES = lib.concatStringsSep "," [
            "forgejo-auto"
            "forgejo-light"
            "forgejo-dark"

            "gitea-auto"
            "gitea-light"
            "gitea-dark"

            "forgejo-auto-deuteranopia-protanopia"
            "forgejo-light-deuteranopia-protanopia"
            "forgejo-dark-deuteranopia-protanopia"

            "forgejo-auto-tritanopia"
            "forgejo-light-tritanopia"
            "forgejo-dark-tritanopia"

            "catppuccin-rosewater-auto"
            "catppuccin-flamingo-auto"
            "catppuccin-pink-auto"
            "catppuccin-mauve-auto"
            "catppuccin-red-auto"
            "catppuccin-maroon-auto"
            "catppuccin-peach-auto"
            "catppuccin-yellow-auto"
            "catppuccin-green-auto"
            "catppuccin-teal-auto"
            "catppuccin-sky-auto"
            "catppuccin-sapphire-auto"
            "catppuccin-blue-auto"
            "catppuccin-lavender-auto"

            "catppuccin-latte-rosewater"
            "catppuccin-latte-flamingo"
            "catppuccin-latte-pink"
            "catppuccin-latte-mauve"
            "catppuccin-latte-red"
            "catppuccin-latte-maroon"
            "catppuccin-latte-peach"
            "catppuccin-latte-yellow"
            "catppuccin-latte-green"
            "catppuccin-latte-teal"
            "catppuccin-latte-sky"
            "catppuccin-latte-sapphire"
            "catppuccin-latte-blue"
            "catppuccin-latte-lavender"
            "catppuccin-frappe-rosewater"
            "catppuccin-frappe-flamingo"
            "catppuccin-frappe-pink"
            "catppuccin-frappe-mauve"
            "catppuccin-frappe-red"
            "catppuccin-frappe-maroon"
            "catppuccin-frappe-peach"
            "catppuccin-frappe-yellow"
            "catppuccin-frappe-green"
            "catppuccin-frappe-teal"
            "catppuccin-frappe-sky"
            "catppuccin-frappe-sapphire"
            "catppuccin-frappe-blue"
            "catppuccin-frappe-lavender"
            "catppuccin-macchiato-rosewater"
            "catppuccin-macchiato-flamingo"
            "catppuccin-macchiato-pink"
            "catppuccin-macchiato-mauve"
            "catppuccin-macchiato-red"
            "catppuccin-macchiato-maroon"
            "catppuccin-macchiato-peach"
            "catppuccin-macchiato-yellow"
            "catppuccin-macchiato-green"
            "catppuccin-macchiato-teal"
            "catppuccin-macchiato-sky"
            "catppuccin-macchiato-sapphire"
            "catppuccin-macchiato-blue"
            "catppuccin-macchiato-lavender"
            "catppuccin-mocha-rosewater"
            "catppuccin-mocha-flamingo"
            "catppuccin-mocha-pink"
            "catppuccin-mocha-mauve"
            "catppuccin-mocha-red"
            "catppuccin-mocha-maroon"
            "catppuccin-mocha-peach"
            "catppuccin-mocha-yellow"
            "catppuccin-mocha-green"
            "catppuccin-mocha-teal"
            "catppuccin-mocha-sky"
            "catppuccin-mocha-sapphire"
            "catppuccin-mocha-blue"
            "catppuccin-mocha-lavender"
          ];
        };

        # TODO:
        # federation = {
        #   ENABLED = true;
        # };
        # TODO:
        # redis as cache/session provider
        # TODO:
        # ENABLE_CAPTCHA = true;
        # CAPTCHA_TYPE = "mcaptcha";
        # REQUIRE_CAPTCHA_FOR_LOGIN = true;
        # REQUIRE_EXTERNAL_REGISTRATION_CAPTCHA = true;
      };
    };

    # provision oauth provider
    systemd.services.forgejo.postStart =
      let
        exe = lib.getExe config.services.forgejo.package;
        provider = {
          provider = "openidConnect";
          name = "kanidm";
          key = cfg.client_id;
          auto-discover-url = idp.oidc_discovery;
          scopes = "profile email groups";
          allow-username-change = true;
          group-claim-name = "groups";
          admin-group = "forgejo.admin@sso.girl.pp.ua";
        };
        providerArgs = lib.cli.toCommandLineShellGNU { } provider;
        providerSecret = config.sops.secrets."forgejo/clientSecret".path;
        customConf = "--work-path ${config.services.forgejo.stateDir} --config ${config.services.forgejo.customDir}/conf/app.ini";
      in
      ''
        provider_id=$(${exe} admin auth list ${customConf} 2>/dev/null | grep -w '${provider.name}' | cut -f1)
        if [[ -z "$provider_id" ]]; then
          echo "adding ${provider.name} ${provider.key}"
          ${exe} admin auth add-oauth ${customConf} ${providerArgs} --secret "$(< ${providerSecret})"
        else
          echo "updating ${provider.name} ${provider.key}"
          ${exe} admin auth update-oauth ${customConf} --id "$provider_id" ${providerArgs} --secret "$(< ${providerSecret})"
        fi
      '';

    # specify secrets explicitly
    systemd.services.forgejo-secrets.script = lib.mkForce "${pkgs.coreutils}/bin/true";

    # custom stuff
    systemd.tmpfiles.rules = [
      "d '${config.services.forgejo.customDir}/public' 0750 ${config.services.forgejo.user} ${config.services.forgejo.group} - -"
      "d '${config.services.forgejo.customDir}/public/assets' 0750 ${config.services.forgejo.user} ${config.services.forgejo.group} - -"
      "L '${config.services.forgejo.customDir}/public/assets/css' - - - - ${catppuccin-gitea}"
    ];

    # confgure caddy
    services.caddy.virtualHosts."http://${cfg.intraDomain}" = {
      serverAliases = [
        "http://${cfg.domain}"
      ];
      extraConfig = ''
        import encode
        reverse_proxy unix/${config.services.forgejo.settings.server.HTTP_ADDR}
      '';
    };

    sops.secrets = {
      "forgejo/secret_key" = { };
      "forgejo/internal_token" = { };
      "forgejo/jwt_secret" = { };
      "forgejo/lfs_jwt_secret" = { };
      "forgejo/clientSecret" = {
        owner = config.services.forgejo.user;
        group = config.services.forgejo.group;
        mode = "0400";
      };
    };
  };
}
