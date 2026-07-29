{ config, lib, ... }:
let
  cfg = config.polaris.services.dashy;
in
{
  options.polaris.services.dashy = {
    enable = lib.mkEnableOption "dashboard";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "dash.lunya.cc";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dashy = {
      enable = true;
      settings = {
        appConfig = {
          cssThemes = [
            "example-theme-1"
            "example-theme-2"
          ];
          enableFontAwesome = true;
          fontAwesomeKey = "e9076c7025";
          theme = "thebe";
        };
        pageInfo = {
          description = "My Awesome Dashboard";
          navLinks = [
            {
              path = "/";
              title = "Home";
            }
            {
              path = "https://example.com";
              title = "Example 1";
            }
            {
              path = "https://example.com";
              title = "Example 2";
            }
          ];
          title = "Dashy";
        };
        sections = [
          {
            displayData = {
              collapsed = true;
              cols = 2;
              customStyles = "border: 2px dashed red;";
              itemSize = "large";
            };
            items = [
              {
                backgroundColor = "#0079ff";
                color = "#00ffc9";
                description = "Source code and documentation on GitHub";
                icon = "fab fa-github";
                target = "sametab";
                title = "Source";
                url = "https://github.com/Lissy93/dashy";
              }
              {
                description = "View currently open issues, or raise a new one";
                icon = "fas fa-bug";
                title = "Issues";
                url = "https://github.com/Lissy93/dashy/issues";
              }
              {
                description = "Live Demo #1";
                icon = "fas fa-rocket";
                target = "iframe";
                title = "Demo 1";
                url = "https://dashy-demo-1.as93.net";
              }
              {
                description = "Live Demo #2";
                icon = "favicon";
                target = "newtab";
                title = "Demo 2";
                url = "https://dashy-demo-2.as93.net";
              }
            ];
            name = "Getting Started";
          }
        ];
      };
    };

    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      import encode
      import norobot
      root * ${config.services.dashy.finalDrv}
      file_server
    '';

  };
}
