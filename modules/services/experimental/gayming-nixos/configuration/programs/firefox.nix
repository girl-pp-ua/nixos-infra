{ ... }:
{
  programs.firefox = {
    enable = true;
    # TODO more config
  };

  gayming.labwc-headless.menuItems = [
    {
      label = "Firefox";
      command = "firefox";
    }
  ];
}
