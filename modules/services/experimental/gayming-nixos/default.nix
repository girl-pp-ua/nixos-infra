# TODO gayming as nixos container
{
  config,
  lib,
  secrets,
  ...
}:
let
  cfg = config.polaris.services.experimental.gayming-nixos;
in
{
  options.polaris.services.experimental.gayming-nixos = {
    enable = lib.mkEnableOption "gayming-nixos";
  };
  config = lib.mkIf cfg.enable {
    boot.enableContainers = true;
    virtualisation.containers.enable = true;
    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-*" ];
      externalInterface = "eth0"; # XXX: this might need to be changed
      # enableIPv6 = true;
    };
    containers.gayming = {
      autoStart = true;
      privateNetwork = true;
      privateUsers = "pick";
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      hostAddress6 = "fc00::1";
      localAddress6 = "fc00::2";
      forwardPorts = [
        {
          containerPort = 3389;
          hostPort = 3389;
          protocol = "tcp";
        }
        {
          containerPort = 3389;
          hostPort = 3389;
          protocol = "udp";
        }
      ];
      additionalCapabilities = [
        "CAP_SYS_NICE"
      ];
      allowedDevices = [
        {
          node = "/dev/dri/renderD128";
          modifier = "rwm";
        }
      ];
      bindMounts = {
        "/dev/dri" = {
          hostPath = "/dev/dri";
          isReadOnly = false;
        };
      };
      config =
        {
          pkgs,
          lib,
          ...
        }:
        {
          system.stateVersion = "26.05";
          boot.isContainer = true;

          networking.firewall = {
            enable = true;
            backend = lib.mkForce "iptables"; # nftables doesn't work in nixos-containers
            checkReversePath = "loose";
          };
          networking.useDHCP = lib.mkForce true;
          networking.useHostResolvConf = lib.mkForce false; # https://github.com/NixOS/nixpkgs/issues/162686
          services.resolved.enable = true;

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];
          nixpkgs.config.allowUnfree = true;

          # hardware
          hardware.uinput.enable = true;

          # graphics
          hardware.graphics = {
            enable = true;
            enable32Bit = true;
          };

          # sys.env
          environment.systemPackages = with pkgs; [
            bashInteractive
            htop
            nano
            git
            nettools
            mesa-demos
            vulkan-tools
          ];

          # fonts
          fonts.enableDefaultPackages = true;

          # sudo
          security.sudo.enable = false;
          security.sudo-rs = {
            enable = true;
            execWheelOnly = true;
          };

          # user
          users = {
            mutableUsers = false;
            users.gamer = {
              isNormalUser = true;
              hashedPassword = secrets.nixos-gayming.gamer_passwd_hash;
              extraGroups = [
                "wheel"
                "video"
                "render"
                "audio"
                "input"
                "uinput"
              ];
              shell = pkgs.bashInteractive;
              # packages = with pkgs; [ ];
            };
          };

          # software
          programs.firefox.enable = true;
          programs.steam = {
            enable = true;
            gamescopeSession.enable = true;
            protontricks.enable = true;
            extest.enable = true;
          };

          # RDP
          services.xrdp = {
            enable = true;
            package = pkgs.callPackage ./xrdp-glamor.nix { };
            openFirewall = true;
            defaultWindowManager = "xfce4-session";
          };

          # X11
          services.xserver = {
            enable = true;
            videoDrivers = [ "amdgpu" ];
            desktopManager = {
              xterm.enable = false;
              xfce.enable = true;
            };
          };

        };
    };

  };
}
