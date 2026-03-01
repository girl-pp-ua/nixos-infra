{ ... }:
{

  fileSystems =
    let
      btrfsOptions = [
        "ssd"
        "noatime"
        "nodiscard" # using fstrim.service instead
        "compress=zstd:1"
      ];
    in
    {
      "/".options = btrfsOptions;
      "/home".options = btrfsOptions;
      "/nix".options = btrfsOptions;
      "/boot".options = [ "noatime" ];
    };
  services.fstrim.enable = true;
}
