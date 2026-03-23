{ pkgs, lib, ... }:
{
  # basic desktop apps
  environment.systemPackages = with pkgs; [
    alacritty
    pcmanfm
    mousepad
    pavucontrol
    wdisplays
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
      label = "PulseAudio Volume Control";
      command = "pavucontrol";
    }
    {
      label = "Display Settings";
      command = "wdisplays";
    }
  ];
}
