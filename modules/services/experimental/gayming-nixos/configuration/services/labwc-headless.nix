{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.gayming.labwc-headless;
in
{
  options.gayming.labwc-headless = {
    enable = lib.mkEnableOption "labwc-headless" // {
      default = true;
    };
    menuItems = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            label = lib.mkOption {
              type = lib.types.str;
              description = "The label of the menu item.";
            };
            command = lib.mkOption {
              type = lib.types.str;
              description = "The command to execute when the menu item is selected.";
            };
          };
        }
      );
      default = [ ];
      description = "Extra menu items to add to the root menu.";
    };
  };
  config = lib.mkIf cfg.enable {
    programs.labwc.enable = true;
    environment.systemPackages = with pkgs; [
      labwc

      # basic desktop apps
      alacritty
      pcmanfm
      mousepad
      pavucontrol
    ];
    systemd.services.labwc-headless =
      let
        labwc-autostart = pkgs.writeShellScript "autostart" ''
          exec ${pkgs.systemd}/bin/systemd-notify READY=1
        '';
        labwc-menu = pkgs.writeText "menu.xml" ''
          <openbox_menu>
          <menu id="client-menu">
            <item label="Minimize">
              <action name="Iconify" />
            </item>
            <item label="Maximize">
              <action name="ToggleMaximize" />
            </item>
            <item label="Fullscreen">
              <action name="ToggleFullscreen" />
            </item>
            <item label="Roll Up/Down">
              <action name="ToggleShade" />
            </item>
            <item label="Decorations">
              <action name="ToggleDecorations" />
            </item>
            <item label="Always on Top">
              <action name="ToggleAlwaysOnTop" />
            </item>
            <menu id="client-send-to-menu"/>
            <item label="Close">
              <action name="Close" />
            </item>
          </menu>

          <menu id="root-menu">
            ${lib.concatStringsSep "\n" (
              map (item: ''
                <item label="${item.label}">
                  <action name="Execute" command="${item.command}" />
                </item>
              '') cfg.menuItems
            )}
          </menu>

          </openbox_menu>
        '';
        labwc-config = pkgs.runCommand "labwc-config" { } ''
          mkdir -p $out
          ln -s ${labwc-autostart} $out/autostart
          ln -s ${labwc-menu} $out/menu.xml
        '';
      in
      {
        description = "Headless labwc";
        wantedBy = [ "default.target" ];
        after = [ "basic.target" ];
        requires = [ "dbus.socket" ];
        wants = [ "dbus.socket" ];
        environment = {
          WLR_BACKENDS = "headless,libinput";
          WLR_LIBINPUT_NO_DEVICES = "1";
          LIBSEAT_BACKEND = "noop";
          LABWC_UPDATE_ACTIVATION_ENV = "1";
          WLR_SCENE_DISABLE_DIRECT_SCANOUT = "0";
          WLR_NO_HARDWARE_CURSORS = "1";
          XDG_RUNTIME_DIR = "/run/user/1000";
          WAYLAND_DISPLAY = "wayland-0";
          DISPLAY = ":0";
          PATH = lib.mkForce "/run/current-system/sw/bin:/usr/bin:/bin";
        };
        serviceConfig = {
          User = "gamer";
          RuntimeDirectory = "user/1000";
          RuntimeDirectoryMode = "0700";
          Type = "simple";
          # Type = "notify";
          # NotifyAccess = "all";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
          ExecStart = "${pkgs.labwc}/bin/labwc -V --debug -C ${labwc-config}";
          KillMode = "mixed";
          TimeoutStopSec = 15;
        };
      };
  };
}
