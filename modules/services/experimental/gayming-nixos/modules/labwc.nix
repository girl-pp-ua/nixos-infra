{ pkgs, lib, ... }:
{
  programs.labwc.enable = true;
  environment.systemPackages = with pkgs; [
    dbus
    labwc
    labwc-tweaks
    alacritty
    pcmanfm
    mousepad
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
          <item label="Terminal">
            <action name="Execute" command="lab-sensible-terminal" />
          </item>
          <item label="File Manager">
            <action name="Execute" command="pcmanfm" />
          </item>
          <item label="Text Editor">
            <action name="Execute" command="mousepad" />
          </item>
          <item label="Web Browser">
            <action name="Execute" command="firefox" />
          </item>

          <separator />
          <item label="Steam">
            <action name="Execute" command="steam" />
          </item>
          <item label="Steam (Big Picture)">
            <action name="Execute" command="steam -bigpicture steam://open/bigpicture" />
          </item>

          <!--
          <separator />
          <item label="Reconfigure">
            <action name="Reconfigure" />
          </item>
          <item label="Exit">
            <action name="Exit" />
          </item>
          -->

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
        AmbientCapabilities = "CAP_SYS_NICE";
      };
    };

}
