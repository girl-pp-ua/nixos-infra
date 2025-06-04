{ pkgs, ... }: let
  cur_rocmPackages = pkgs.rocmPackages;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "24.11";

  # kernel param
  boot.kernelParams = [
    "nohibernate" # HACK: disable hibernation
    "amd_pstate=active"
  ];

  # opencl
  # i'm overriding the default opencl option to use rocm 5 instead:
  hardware.amdgpu.opencl.enable = false;
  hardware.graphics.extraPackages = [
    cur_rocmPackages.clr
    cur_rocmPackages.clr.icd
  ];

  # hip/rocm
  systemd.tmpfiles.rules = let
    rocmEnv = pkgs.symlinkJoin {
      name = "rocm-combined";
      paths = with cur_rocmPackages; [ rocblas hipblas clr ];
    };
  in [
    "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
  ];

  # fs
  fileSystems = let
    btrfsOptions = [ "ssd" "noatime" "nodiscard" "compress=zstd:1" ];
  in {
    "/".options = btrfsOptions;
    "/home".options = btrfsOptions;
    "/nix".options =  btrfsOptions;
    "/boot".options = [ "noatime" ];
  };

  # services
  services.fstrim.enable = true;
  # services.thermald.enable = true;
  services.fwupd.enable = true;

  # cpu
  hardware.cpu.amd.updateMicrocode = true;

  # reduce swappiness
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };

  # HACK: wifi
  networking.networkmanager.wifi.powersave = false;
  boot.extraModprobeConfig = ''
    options rtw88_core disable_lps_deep=y
    options rtw88_pci disable_msi=y disable_aspm=y
    options rtw_core disable_lps_deep=y
    options rtw_pci disable_msi=y disable_aspm=y
  '';
}
