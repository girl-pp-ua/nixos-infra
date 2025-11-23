{ ... }:
{
  # security.sudo = {
  #   enable = true;
  #   execWheelOnly = true;
  #   wheelNeedsPassword = false;
  # };
  security.sudo.enable = false;
  security.sudo-rs = {
    enable = true;
    execWheelOnly = true;
    wheelNeedsPassword = false;
  };
}
