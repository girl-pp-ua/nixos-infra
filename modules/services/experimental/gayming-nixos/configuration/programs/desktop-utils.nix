{ pkgs, lib, ... }:
{
  # basic desktop apps
  environment.systemPackages = with pkgs; [
    alacritty
    pcmanfm
    mousepad
    pavucontrol
    wdisplays
    jstest-gtk
    antimicrox
  ];

  gayming.labwc-headless.menuItems = lib.mkBefore [
    {
      label = "Terminal";
      command = "alacritty";
    }
    {
      label = "File Manager";
      command = "pcmanfm";
    }
    {
      label = "Text Editor";
      command = "mousepad";
    }
    {
      label = "Audio Settings";
      command = "pavucontrol";
    }
    {
      label = "Display Settings";
      command = "wdisplays";
    }
    {
      label = "Gamepad Test";
      command = "jstest-gtk";
    }
    {
      label = "AntiMicroX";
      command = "antimicrox";
    }
  ];
}
