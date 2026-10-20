{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg-nextcloud = config.polaris.services.nextcloud;
in
{
  config = lib.mkIf cfg-nextcloud.enable {
    services.nextcloud = {
      imaginary.enable = true;

      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          previewgenerator
          ;
      };

      settings = {
        enable_previews = true;

        # cap preview resolution (default: 4096)
        preview_max_x = 2048;
        preview_max_y = 2048;

        preview_ffmpeg_path = "${pkgs.ffmpeg}/bin/ffmpeg";
        # broken: cannot create directory '/run/user/989': Permission denied
        # preview_libreoffice_path = "${pkgs.libreoffice}/bin/libreoffice";

        enabledPreviewProviders = [
          # Imaginary (libvips)
          "OC\\Preview\\Imaginary"
          "OC\\Preview\\ImaginaryPDF"

          # Misc
          "OC\\Preview\\RIFF"

          # https://help.nextcloud.com/t/preview-settings-not-described-well/197952/9

          # No External Dependencies
          "OC\\Preview\\PNG"
          "OC\\Preview\\JPEG"
          "OC\\Preview\\GIF"
          "OC\\Preview\\BMP"
          "OC\\Preview\\XBitmap"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\MP3"
          "OC\\Preview\\TXT"
          "OC\\Preview\\Krita"

          # ImageMagick Dependency
          "OC\\Preview\\SVG"
          "OC\\Preview\\TIFF"
          "OC\\Preview\\PDF"
          "OC\\Preview\\Illustrator"
          "OC\\Preview\\Photoshop"
          "OC\\Preview\\Postscript"
          "OC\\Preview\\Font"
          "OC\\Preview\\HEIC"
          "OC\\Preview\\TGA"
          "OC\\Preview\\SGI"

          # Office Dependency (preview_libreoffice_path)
          # (not needed with onlyoffice DocumentServer)
          # "OC\\Preview\\MSOfficeDoc"
          # "OC\\Preview\\MSOffice2003"
          # "OC\\Preview\\MSOffice2007"
          # "OC\\Preview\\OpenDocument"
          # "OC\\Preview\\StarOffice"
          # "OC\\Preview\\EMF"

          # AVConf/FFmpeg Dependency
          "OC\\Preview\\Movie"

          # Additional Providers
          "OC\\Preview\\WebP" # Requires PHP support for WebP images (php-gd)
        ];
      };
    };

    # pre-generate previews for new files in the background
    systemd.services.nextcloud-preview-pregenerate = {
      after = [ "nextcloud-setup.service" ];
      startAt = "*:0/10";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe config.services.nextcloud.occ} preview:pre-generate";
        User = "nextcloud";
        inherit (config.systemd.services.nextcloud-cron.serviceConfig) LoadCredential;
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };
  };
}
