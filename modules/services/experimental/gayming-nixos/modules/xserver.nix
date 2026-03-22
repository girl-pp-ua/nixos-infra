{ ... }:
{
  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
  };
}
