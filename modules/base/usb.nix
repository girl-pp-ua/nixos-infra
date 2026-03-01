{ ... }:
{
  boot.kernelParams = [
    "usbcore.autosuspend=-1" # disable usb autosuspend
  ];
  services.udev.extraRules = ''
    # disable usb autosuspend
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
  '';
}
