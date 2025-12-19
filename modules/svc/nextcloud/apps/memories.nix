{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.nix-infra.svc.nextcloud.app.notify-push;
  exiftool_12_70 = pkgs.exiftool.overrideAttrs (old: rec {
    version = "12.70";
    src = pkgs.fetchFromGitHub {
      owner = "exiftool";
      repo = "exiftool";
      tag = version;
      hash = "sha256-YMWYPI2SDi3s4KCpSNwovemS5MDj5W9ai0sOkvMa8Zg=";
    };
  });
in
{
  options.nix-infra.svc.nextcloud.app.memories = {
    enable = lib.mkEnableOption "nextcloud memories";
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps) memories;
      };
      settings = {
        "memories.readonly" = true;
        "memories.exiftool" = "${exiftool_12_70}/bin/exiftool";
        "memories.vod.disable" = true; # TODO fix; probably needs go-vod
        "memories.vod.vaapi" = config.hardware.graphics.enable;
        "memories.vod.ffmpeg" = "${pkgs.ffmpeg}/bin/ffmpeg";
        "memories.vod.ffprobe" = "${pkgs.ffmpeg}/bin/ffprobe";
      };
    };
  };
}
