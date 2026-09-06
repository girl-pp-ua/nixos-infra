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
    fwdHostGids = lib.mkEnableOption "forward host gids" // {
      default = !cfg.vuinputd.enable;
    };
    vuinputd.enable = lib.mkEnableOption "vuinputd" // {
      default = false;
      description = "Use vuinputd for virtual input devices instead of exposing /dev/uinput directly";
    };
  };
  imports = [
    ./uinput-base.nix
    ./uinput-raw.nix
    ./uinput-vuinputd.nix
  ];
  config = lib.mkIf cfg.enable {
    assertions =
      map
        (name: {
          assertion = cfg.fwdHostGids -> config.users.groups.${name}.gid != null;
          message = "gayming-nixos: host group '${name}' has no static gid";
        })
        [
          "input"
          "uinput"
        ];

    polaris.services.backup.extraExclude = [
      "/var/lib/nixos-containers/gayming"
    ];

    boot.enableContainers = true;
    virtualisation.containers.enable = true;

    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-*" ];
      externalInterface = "eth0"; # XXX: this might need to be changed
      enableIPv6 = true;
    };

    # see forwardPorts below
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [
        48010
        27036
        27037
      ];
      allowedUDPPorts = [
        48010
        27036
        10400
        10401
      ];
      allowedTCPPortRanges = [
        {
          from = 47984;
          to = 47990;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 47998;
          to = 48000;
        }
        {
          from = 27031;
          to = 27035;
        }
      ];
    };

    containers.gayming = {
      autoStart = true;
      privateNetwork = true;
      # TODO fix input with privateUsers?
      # privateUsers = "pick";
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      hostAddress6 = "fc00::1";
      localAddress6 = "fc00::2";
      forwardPorts =
        let
          forward = protocol: port: {
            containerPort = port;
            hostPort = port;
            inherit protocol;
          };
          tcp = forward "tcp";
          udp = forward "udp";
        in
        [
          # Sunshine
          # 47984-47990/tcp
          (tcp 47984)
          (tcp 47985)
          (tcp 47986)
          (tcp 47987)
          (tcp 47988)
          (tcp 47989)
          (tcp 47990)
          # 48010:48010/tcp,udp
          (tcp 48010)
          (udp 48010)
          # 47998-48000/udp
          (udp 47998)
          (udp 47999)
          (udp 48000)

          # Steam
          # peer discovery
          (udp 27036)
          # remote play
          (tcp 27036)
          (tcp 27037)
          (udp 10400)
          (udp 10401)
          (udp 27031)
          (udp 27032)
          (udp 27033)
          (udp 27034)
          (udp 27035)
        ];
      additionalCapabilities = [
        "CAP_SYS_NICE"
      ];
      allowedDevices = [
        {
          node = "/dev/dri/renderD128";
          modifier = "rw";
        }
        {
          node = "char-drm";
          modifier = "rw";
        }
        {
          node = "char-input";
          modifier = "rw";
        }
        {
          node = "char-hidraw";
          modifier = "rw";
        }
        {
          node = "/dev/fuse";
          modifier = "rw";
        }
      ]
      ++ (
        if cfg.vuinputd.enable then
          [
            {
              node = "/dev/vuinput";
              modifier = "rw";
            }
          ]
        else
          [
            {
              node = "/dev/uinput";
              modifier = "rw";
            }
            {
              node = "/dev/uhid";
              modifier = "rw";
            }
          ]
      );
      bindMounts = {
        "/dev/dri" = {
          hostPath = "/dev/dri";
          isReadOnly = false;
        };
        "/dev/input" = {
          hostPath = "/dev/input";
          isReadOnly = false;
        };
        "/dev/fuse" = {
          hostPath = "/dev/fuse";
          isReadOnly = false;
        };
      }
      // (
        if cfg.vuinputd.enable then
          {
            "/dev/uinput" = {
              hostPath = "/dev/vuinput";
              isReadOnly = false;
            };
          }
        else
          {
            "/dev/uinput" = {
              hostPath = "/dev/uinput";
              isReadOnly = false;
            };
            "/dev/uhid" = {
              hostPath = "/dev/uhid";
              isReadOnly = false;
            };
            "/run/udev" = {
              hostPath = "/run/udev";
              isReadOnly = true;
            };
          }
      );
      specialArgs = {
        inherit secrets;
        inherit (cfg) fwdHostGids;
        useVuinputd = cfg.vuinputd.enable;
        hostInputGid = config.users.groups.input.gid;
        hostUinputGid = config.users.groups.uinput.gid;
      };
      config =
        { ... }:
        {
          imports = [
            ./configuration
          ];
        };
    };

  };
}
