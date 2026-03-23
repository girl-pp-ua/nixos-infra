{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    eden
    ryubing
    steam-rom-manager
  ];
  gayming.labwc-headless.menuItems = [
    {
      label = "[switch] Eden";
      command = "eden";
    }
    {
      label = "[switch] Ryujinx";
      command = "ryujinx";
    }
    {
      label = "Steam ROM Manager";
      command = "steam-rom-manager";
    }
  ];

}
