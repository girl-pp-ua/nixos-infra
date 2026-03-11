# TODO gayming as nixos container
{
  config,
  lib,
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
      internalInterfaces = [ "ve-+" ];
      externalInterface = "eth0"; # XXX: this might need to be changed
      enableIPv6 = true;
    };
    containers.gayming = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      hostAddress6 = "fc00::1";
      localAddress6 = "fc00::2";
      config =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          system.stateVersion = "26.05";
          boot.isContainer = true;

          # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
          networking.useHostResolvConf = lib.mkForce false;
          services.resolved.enable = true;

          hardware.uinput.enable = true;

          programs.steam = {
            enable = true;
            gamescopeSession.enable = true;
            protontricks.enable = true;
            extest.enable = true;
          };

        };
    };

  };
}
