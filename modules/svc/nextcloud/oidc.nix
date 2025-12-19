{
  lib,
  libx,
  config,
  ...
}:
let
  cfg-nextcloud = config.nix-infra.svc.nextcloud;
  cfg-kanidm = config.nix-infra.svc.kanidm;
  idp = libx.idp {
    inherit (cfg-kanidm) domain;
    inherit (cfg-nextcloud) client_id;
  };
in
{
  config = lib.mkIf cfg-nextcloud.enable {
    services.nextcloud = {
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          user_oidc
          ;
      };
      settings = {
        user_oidc = {
          login_label = "Log in with ${cfg-kanidm.domain}";
          enrich_login_id_token_with_userinfo = true;
          userinfo_bearer_validation = true;
          auto_provision = true;
          soft_auto_provision = true; # allow login into existing accounts
          allow_multiple_user_backends = false;
        };

        hide_login_form = true; # use ?direct=1 to bypass/login as root
        "auth.webauthn.enabled" = false; # using only oidc, that already uses webauthn
        allow_user_to_change_display_name = false; # does not work with oidc
        lost_password_link = "disabled";
      };
      extraOCCCommands = ''
        occ user_oidc:provider girlcock \
          --discoveryuri="${idp.oidc_discovery}" \
          --clientid="${cfg-nextcloud.client_id}" \
          --clientsecret=$(cat "${config.sops.secrets."nextcloud/clientSecret".path}") \
          --scope "profile email groups openid" \
          --unique-uid 0 \
          --group-provisioning 1 \
          --group-whitelist-regex "nextcloud\..*" \
          --group-restrict-login-to-whitelist 1 \
          --mapping-uid "preferred_username";
      '';
    };
  };
}
