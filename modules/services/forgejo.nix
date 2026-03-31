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
      database.createDatabase = true;
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
        };
        security = {
          INSTALL_LOCK = true;
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
          ACCOUNT_LINKING = "auto";
          USERNAME = "nickname"; # preferred_username?
          UPDATE_AVATAR = true;
        };
        # oauth2 = {
        #   JWT_SIGNING_ALGORITHM = "ES256";
        # };
        repository = {
          DEFAULT_BRANCH = "master"; # sorry im too used to this one :p
        };
        indexer = {
          REPO_INDEXER_ENABLED = true;
          REPO_INDEXER_FUZZY_ENABLED = true;
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
          skip-local-2fa = true;
          allow-username-change = true;
          admin-group = "forgejo_admin";
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
