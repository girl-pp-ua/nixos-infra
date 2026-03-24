{ ... }:
{
  security.sudo.enable = false;
  security.sudo-rs = {
    enable = true;
    execWheelOnly = true;
  };
  security.polkit.enable = true;
}
