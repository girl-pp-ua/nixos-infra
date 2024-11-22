{ pkgs, lib, ... }: {
  services.netdata = {
    enable = true;
    enableAnalyticsReporting = lib.mkForce false;
    python = {
      enable = true;
      recommendedPythonPackages = true;
    };
  };
  environment.systemPackages = with pkgs; [
    netdata
  ];
}