{ pkgs, ... }: {
  imports = [
    # Base configuration
    ./boot.nix
    ./system.nix
    ./networking.nix
    ./nix.nix
    ./users.nix
    ./sudo.nix

    # Base services
    ./services/openssh.nix
    ./services/sshguard.nix
    ./services/tailscale.nix
    ./services/caddy.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "UTC";

  programs = {
    fish.enable = true;
    git.enable = true;
    command-not-found.enable = false;
    mosh = {
      enable = true;
      openFirewall = true;
    };
  };

  environment = {
    systemPackages = with pkgs; [
      nano
      htop
      curl
      wget
      hyfetch
    ];

    variables = {
      EDITOR = "nano";
      BROWSER = "echo"; # print the url
    };

    # disable the informative message when running non-nixos binaries
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
}