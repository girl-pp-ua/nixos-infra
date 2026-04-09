{ config, lib, ... }:
let
  cfg = config.polaris.services.caddy.endpoints.proxies;
  cfg' = config.polaris.services;
in
{
  options.polaris.services.caddy.endpoints.proxies = {
    enable = lib.mkEnableOption "caddy nc proxy endpoint";
  };
  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts = {
      ${cfg'.nextcloud.domain}.extraConfig = ''
        import encode
        @dist {
          path ${
            lib.concatStringsSep " " [
              "/core/robots.txt"
              "/dist/*"
              "/core/css/*"
              "/core/js/*"
              "/core/fonts/*"
              "/core/vendor/*"
              "/core/skeleton/*"
              "/core/doc/*"
              "/core/l10n/*"
              "/apps/activity/img/*"
              "/apps/app_api/img/*"
              "/apps/circles/img/*"
              "/apps/comments/img/*"
              "/apps/dashboard/img/*"
              "/apps/dav/img/*"
              "/apps/encryption/img/*"
              "/apps/federatedfilesharing/img/*"
              "/apps/federation/img/*"
              "/apps/files/img/*"
              "/apps/files_external/img/*"
              "/apps/files_pdfviewer/img/*"
              "/apps/files_reminders/img/*"
              "/apps/files_sharing/img/*"
              "/apps/files_trashbin/img/*"
              "/apps/files_versions/img/*"
              "/apps/firstrunwizard/img/*"
              "/apps/logreader/img/*"
              "/apps/nextcloud_announcements/img/*"
              "/apps/notifications/img/*"
              "/apps/password_policy/img/*"
              "/apps/photos/img/*"
              "/apps/privacy/img/*"
              "/apps/provisioning_api/img/*"
              "/apps/serverinfo/img/*"
              "/apps/settings/img/*"
              "/apps/sharebymail/img/*"
              "/apps/support/img/*"
              "/apps/survey_client/img/*"
              "/apps/suspicious_login/img/*"
              "/apps/systemtags/img/*"
              "/apps/testing/img/*"
              "/apps/text/img/*"
              # "/apps/theming/img/*"
              "/apps/twofactor_nextcloud_notification/img/*"
              "/apps/twofactor_totp/img/*"
              "/apps/updatenotification/img/*"
              "/apps/user_ldap/img/*"
              "/apps/user_status/img/*"
              "/apps/viewer/img/*"
              "/apps/weather_status/img/*"
              "/apps/webhook_listeners/img/*"
              "/apps/workflowengine/img/*"
              "/apps/activity/css/*"
              "/apps/app_api/css/*"
              "/apps/circles/css/*"
              "/apps/dashboard/css/*"
              "/apps/dav/css/*"
              "/apps/encryption/css/*"
              "/apps/federation/css/*"
              "/apps/files_downloadlimit/css/*"
              "/apps/files_pdfviewer/css/*"
              "/apps/files_sharing/css/*"
              "/apps/firstrunwizard/css/*"
              "/apps/logreader/css/*"
              "/apps/notifications/css/*"
              "/apps/password_policy/css/*"
              "/apps/photos/css/*"
              "/apps/related_resources/css/*"
              "/apps/serverinfo/css/*"
              "/apps/settings/css/*"
              "/apps/support/css/*"
              "/apps/survey_client/css/*"
              "/apps/text/css/*"
              "/apps/theming/css/*"
              "/apps/twofactor_backupcodes/css/*"
              "/apps/twofactor_totp/css/*"
              "/apps/viewer/css/*"
              "/apps/activity/js/*"
              "/apps/app_api/js/*"
              "/apps/bruteforcesettings/js/*"
              "/apps/circles/js/*"
              "/apps/files_downloadlimit/js/*"
              "/apps/files_pdfviewer/js/*"
              "/apps/firstrunwizard/js/*"
              "/apps/logreader/js/*"
              "/apps/notifications/js/*"
              "/apps/password_policy/js/*"
              "/apps/photos/js/*"
              "/apps/privacy/js/*"
              "/apps/recommendations/js/*"
              "/apps/related_resources/js/*"
              "/apps/serverinfo/js/*"
              "/apps/settings/js/*"
              "/apps/support/js/*"
              "/apps/survey_client/js/*"
              "/apps/text/js/*"
              "/apps/twofactor_nextcloud_notification/js/*"
              "/apps/twofactor_totp/js/*"
              "/apps/viewer/js/*"
              "/apps/activity/l10n/*"
              "/apps/admin_audit/l10n/*"
              "/apps/app_api/l10n/*"
              "/apps/bruteforcesettings/l10n/*"
              "/apps/circles/l10n/*"
              "/apps/cloud_federation_api/l10n/*"
              "/apps/comments/l10n/*"
              "/apps/contactsinteraction/l10n/*"
              "/apps/dashboard/l10n/*"
              "/apps/dav/l10n/*"
              "/apps/encryption/l10n/*"
              "/apps/federatedfilesharing/l10n/*"
              "/apps/federation/l10n/*"
              "/apps/files/l10n/*"
              "/apps/files_downloadlimit/l10n/*"
              "/apps/files_external/l10n/*"
              "/apps/files_pdfviewer/l10n/*"
              "/apps/files_reminders/l10n/*"
              "/apps/files_sharing/l10n/*"
              "/apps/files_trashbin/l10n/*"
              "/apps/files_versions/l10n/*"
              "/apps/firstrunwizard/l10n/*"
              "/apps/logreader/l10n/*"
              "/apps/lookup_server_connector/l10n/*"
              "/apps/nextcloud_announcements/l10n/*"
              "/apps/notifications/l10n/*"
              "/apps/oauth2/l10n/*"
              "/apps/password_policy/l10n/*"
              "/apps/photos/l10n/*"
              "/apps/privacy/l10n/*"
              "/apps/profile/l10n/*"
              "/apps/provisioning_api/l10n/*"
              "/apps/recommendations/l10n/*"
              "/apps/related_resources/l10n/*"
              "/apps/serverinfo/l10n/*"
              "/apps/settings/l10n/*"
              "/apps/sharebymail/l10n/*"
              "/apps/support/l10n/*"
              "/apps/survey_client/l10n/*"
              "/apps/suspicious_login/l10n/*"
              "/apps/systemtags/l10n/*"
              "/apps/text/l10n/*"
              "/apps/theming/l10n/*"
              "/apps/twofactor_backupcodes/l10n/*"
              "/apps/twofactor_nextcloud_notification/l10n/*/*"
              "/apps/twofactor_totp/l10n/*"
              "/apps/updatenotification/l10n/*"
              "/apps/user_ldap/l10n/*"
              "/apps/user_status/l10n/*"
              "/apps/viewer/l10n/*"
              "/apps/weather_status/l10n/*"
              "/apps/webhook_listeners/l10n/*"
              "/apps/workflowengine/l10n/*"
              "/apps/activity/docs/*"
              "/apps/notifications/docs/*"
            ]
          }
        }
        handle @dist {
          import norobot
          root * ${cfg'.nextcloud.package}

          @immutable {
            path *.css *.js *.mjs *.svg *.gif *.png *.jpg *.ico *.wasm *.tflite
            query v=*
          }
          header @immutable Cache-Control "max-age=15778463, immutable"

          @static {
            path *.css *.js *.mjs *.svg *.gif *.png *.jpg *.ico *.wasm *.tflite
            not query v=*
          }
          header @static Cache-Control "max-age=15778463"

          @woff2 path *.woff2
          header @woff2 Cache-Control "max-age=604800"

          file_server
        }

        reverse_proxy http://${cfg'.nextcloud.intraDomain}
      '';
      ${cfg'.paperless.domain}.extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://${cfg'.paperless.intraDomain}
      '';
      ${cfg'.immich.domain}.extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://${cfg'.immich.intraDomain}
      '';
      ${cfg'.forgejo.domain}.extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://${cfg'.forgejo.intraDomain}
      '';
    };
  };
}
