{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    dns-server.enable = true; # (for the .polaris zone)
    nextcloud.enable = true;
    paperless.enable = true;
    immich.enable = true;
    forgejo.enable = true;
    home-assistant = {
      enable = true;
      # zbt-1, flashed with openthread rcp firmware
      matter.threadRadio = "/dev/serial/by-id/usb-Nabu_Casa_SkyConnect_v1.0_ec9d0ed490e5ed119ed6646262c613ac-if00-port0";
    };

    backup = {
      enable = true;
      repo = "/mnt/data/backups";
    };

    # experimental stuff:
    experimental = {
      gayming-nixos = {
        enable = true;
        # vuinputd.enable = true;
      };
      # hydra.enable = true;
    };
  };
}
