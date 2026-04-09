{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg-nextcloud = config.polaris.services.nextcloud;

  appConfig = {
    # Global
    default-enabled = true; # The menu is enabled by default for users
    force = true; # Force this configuration to users
    loader-enabled = true; # Loader enabled

    # Panel
    # Type:
    always-displayed = false;
    big-menu = false;
    side-with-categories = false;
    # Logo
    display-logo = false;
    add-logo-link = true;
    use-avatar = true; # use avatar for logo
    show-settings = true;
    # Icons/Texts
    size-icon = "big";
    size-text = "normal";

    # Categories
    apps-order = [
      "dashboard"
      "files"
      "photos"
      "integration_immich"
      "calendar"
      "tasks"
      "deck"
      "notes"
      "contacts"
      "bookmarks"
      "forms"
      "tables"
      "activity"
    ];
    big-menu-hidden-apps = [ ];
    target-blank-apps = [ "0" ]; # ?
    apps-categories-custom = {
      files = null;
      dashboard = null;
      photos = null;
      integration_immich = null;
      tables = null;
      calendar = null;
      tasks = null;
      deck = null;
      notes = null;
      contacts = null;
      bookmarks = null;
      forms = null;
      activity = null;
    };
    categories-custom = [ ];
    categories-order = [ ];
    categories-order-type = "default";

    # Colors
    background-color = "#CCD0DA";
    background-color-opacity = 100;
    background-color-to = "#CCD0DA";
    current-app-background-color = "#c49cb9";
    icon-invert-filter = 0;
    icon-opacity = 100;
    loader-color = "#f7cfec";
    text-color = "#000000";
    # Dark mode colors
    dark-mode-background-color = "#313244";
    dark-mode-background-color-opacity = 100;
    dark-mode-background-color-to = "#313244";
    dark-mode-current-app-background-color = "#ac88a2";
    dark-mode-icon-invert-filter = 0;
    dark-mode-icon-opacity = 100;
    dark-mode-loader-color = "#f7cfec";
    dark-mode-text-color = "#FFFFFF";

    # Opener
    opener = "side-menu-opener";
    dark-mode-opener = "side-menu-opener";
    opener-position = "before";
    opener-only = false; # Show only the opener (hidden logo)
    opener-hover = false; # Open the menu when the mouse is hover the opener

    # Top Menu
    # Applications kept in the top menu
    top-menu-apps = [
      "2"
      "files"
      "photos"
      "calendar"
      "deck"
      "tasks"
      "notes"
    ];
    # Applications kept in the top menu but also shown in side menu
    top-side-menu-apps = [
      "2"
      "files"
      "photos"
      "calendar"
      "deck"
      "tasks"
      "notes"
    ];
    # Hide labels on mouse over (0 = Yes, 1 = No, 2 = Except the hovered app)
    top-menu-mouse-over-hidden-label = 2;

    # Misc.
    external-sites-in-top-menu = false; # ?
    force-light-icon = false; # ?
  };

  configJSON = pkgs.writeText "config.json" (
    lib.toJSON {
      system = { };
      apps.side_menu = (
        builtins.mapAttrs (
          name: value:
          if builtins.isString value then
            value
          else if builtins.isBool value then
            (if value then "1" else "0")
          else
            builtins.toJSON value
        ) appConfig
      );
    }
  );
in
{
  config = lib.mkIf cfg-nextcloud.enable {
    services.nextcloud = {
      extraApps = {
        inherit (cfg-nextcloud.apps-packages)
          side_menu
          ;
      };
      extraOCCCommands = ''
        occ config:import ${configJSON}
      '';
    };
  };
}
