{ pkgs, ... }:
{
  services.xserver = {
    enable = true;
    videoDrivers = [ "dummy" ];

    # Dummy screen
    # monitorSection = ''
    #   VendorName     "Unknown"
    #   HorizSync   30-85
    #   VertRefresh 48-120

    #   ModelName      "Unknown"
    #   Option         "DPMS"
    # '';

    # deviceSection = ''
    #   VendorName     "AMD"
    #   Option      "AllowEmptyInitialConfiguration"
    #   Option      "ConnectedMonitor" "DFP"
    #   Option      "CustomEDID" "DFP-0"
    # '';

    # screenSection = ''
    #   DefaultDepth    24
    #   Option      "ModeValidation" "AllowNonEdidModes, NoVesaModes"
    #   Option      "MetaModes" "1920x1080"
    #   SubSection     "Display"
    #       Depth       24
    #   EndSubSection
    # '';

    # inputClassSections = [
    #   ''
    #     Identifier "ContainerKeyboards"
    #     MatchIsKeyboard "on"
    #     Driver "evdev"
    #   ''
    #   ''
    #     Identifier "ContainerPointers"
    #     MatchIsPointer "on"
    #     Driver "evdev"
    #   ''
    # ];
  };

  services.xserver.desktopManager.xfce = {
    enable = true;
    enableScreensaver = false;
  };

  # services.xserver.displayManager.startx = {
  #   enable = true;
  #   generateScript = true;
  # };
  services.displayManager = {
    defaultSession = "xfce";
    autoLogin = {
      enable = true;
      user = "gamer";
    };
    # gdm = {
    #   enable = true;
    #   wayland = false;
    #   autoSuspend = false;
    # };
  };
}
