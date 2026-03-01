{ pkgs, ... }:
let
  cur_rocmPackages = pkgs.rocmPackages;
in
{
  # this system has a gpu :3
  hardware.graphics.enable = true;

  # opencl
  hardware.amdgpu.opencl.enable = cur_rocmPackages == pkgs.rocmPackages;
  hardware.graphics.extraPackages = [
    cur_rocmPackages.clr
    cur_rocmPackages.clr.icd
  ];

  # hip/rocm
  systemd.tmpfiles.rules =
    let
      rocmEnv = pkgs.symlinkJoin {
        name = "rocm-combined";
        paths = with cur_rocmPackages; [
          rocblas
          hipblas
          clr
        ];
      };
    in
    [
      "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
    ];
}
