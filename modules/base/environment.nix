{ pkgs, ... }: {
  programs = {
    fish.enable = true;
    git.enable = true;
    mosh = {
      enable = true;
      openFirewall = true;
    };
  };
  environment = {
    systemPackages = with pkgs; [
      nano
      htop
      curl
      wget
      hyfetch
      httpie
    ];
    variables = {
      EDITOR = "nano";
      BROWSER = "echo"; # print the url
    };
  };
}