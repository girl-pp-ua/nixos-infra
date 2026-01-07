{
  inputs,
  pkgs,
  lib,
  config,
  root,
  ...
}:
let
  cfg-nextcloud = config.polaris.services.nextcloud;
  colors = {
    primary = "#f5c2e7";
    background = "#1e1e2e";
  };
  customcss = ''
    body {
      --color-primary-element: rgb(var(--color-primary-element-rgb));
      --color-main-background: rgb(var(--color-main-background-rgb));
      --color-main-background-translucent: rgba(var(--color-main-background-rgb), 0.95);
    }

    @media (prefers-color-scheme: dark) {
      body {
        --color-primary-element-rgb: 245, 194, 231;
        --color-main-background-rgb: 30, 30, 46;
        --color-main-background-blur: rgba(24, 24, 37, 0.95);
      }
    }

    @media (prefers-color-scheme: light) {
      body {
        --color-primary-element-rgb: 234, 118, 203;
        --color-main-background-rgb: 239, 241, 245;
        --color-main-background-blur: rgba(230, 233, 239, 0.95);
      }
    }

    /* #app-navigation:not(.vue), .app-navigation {
      backdrop-filter: unset !important;
    } */
  '';
in
{
  config = lib.mkIf cfg-nextcloud.enable {
    services.nextcloud = {
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          theming_customcss
          unroundedcorners
          ;
      };
      extraOCCCommands = ''
        occ theming:config name "Girlcloud"
        occ theming:config primary_color "${colors.primary}"
        occ theming:config background backgroundColor
        occ theming:config background "${root}/assets/wallpapers/yuri3.webp"
        occ theming:config background_color "${colors.background}"

        customcss="${pkgs.writeText "customcss.css" customcss}";
        occ config:app:set theming_customcss customcss --value "$(cat $customcss)"
        occ config:app:set theming_customcss cachebuster --value "$(md5sum $customcss)"
      '';
    };
  };
}
