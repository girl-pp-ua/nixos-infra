{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.cfg.services.supervisor-host;
in
{
  options.cfg.services.supervisor-host = {
    enable = lib.mkEnableOption "supervisor-host";
    gpuPassthrough = lib.mkEnableOption "amd gpuPassthrough";
    cockpit = {
      port = lib.mkOption {
        type = lib.types.int;
        default = 9090;
        description = "Port for Cockpit service";
      };
      intraDomain = lib.mkOption {
        type = lib.types.str;
        default = "cockpit.nix-infra";
        description = "Domain for Cockpit service";
      };
    };
  };

  config =
    (lib.mkIf cfg.enable {
      # Enable virtualization
      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          ovmf = {
            enable = true;
            packages = [ pkgs.OVMFFull.fd ];
          };
          swtpm.enable = true;
          runAsRoot = false;
        };
      };

      # Enable Cockpit
      services.cockpit = {
        enable = true;
        inherit (cfg.cockpit) port;
        showBanner = false;
        settings = {
          WebService = {
            AllowUnencrypted = true;
            ForwardedForHeader = "X-Forwarded-For";
            ProtocolHeader = "X-Forwarded-Proto";
            Origins = "http://${cfg.cockpit.intraDomain}";
          };
        };
      };

      environment.systemPackages = with pkgs; [
        cockpit-machines
      ];

      # Add your user to necessary groups
      users.users.nixos.extraGroups = [
        "libvirtd"
        "kvm"
        "qemu-libvirtd"
      ];

      # Enable nested virtualization (optional but recommended)
      boot.extraModprobeConfig = ''
        options kvm_amd nested=1
      '';

      services.caddy.virtualHosts = {
        "http://${cfg.cockpit.intraDomain}" = {
          extraConfig = ''
            import encode
            reverse_proxy http://127.0.0.1:${toString cfg.cockpit.port}
          '';
        };
      };

    })
    // (lib.mkIf (cfg.enable && cfg.gpuPassthrough) {
      # Enable IOMMU (AMD)
      boot.kernelParams = [
        "amd_iommu=on"
        "iommu=pt"
        "video=efifb:off" # Disable EFI framebuffer to free the GPU
      ];

      # Load VFIO modules early
      boot.initrd.kernelModules = [
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"
      ];

      # Bind GPU to VFIO at boot
      boot.extraModprobeConfig = ''
        options vfio-pci ids=1002:15e7,1002:1637
        softdep amdgpu pre: vfio-pci
        softdep snd_hda_intel pre: vfio-pci
      '';

      # Blacklist AMD GPU drivers on host
      boot.blacklistedKernelModules = [ "amdgpu" ];
    });
}
