{ ... }:
{
  imports = [
    ./sops.nix

    # Base configuration
    ./networking
    ./boot.nix
    ./nix.nix
    ./users.nix
    ./sudo.nix
    ./environment.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "UTC";

  # disable command-not-found
  programs.command-not-found.enable = false;

  # disable the informative message when running non-nixos binaries
  environment = {
    stub-ld.enable = false;
    ldso32 = null; # don't install the /lib/ld-linux.so.2 stub
  };

  # disable documentation, skips man page generation
  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
  };

  # disable fontconfig
  fonts = {
    fontconfig.enable = false;
    enableDefaultPackages = false;
  };

  # disable xdg desktop stuff
  xdg = {
    autostart.enable = false;
    icons.enable = false;
    menus.enable = false;
    mime.enable = false;
    sounds.enable = false;
  };

  # disable suspend and hibernate
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
  '';

  # disable the lid switch (if present)
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";
  };

  # limit journald log size
  services.journald.extraConfig = ''
    SystemMaxUse=1G
  '';
}
