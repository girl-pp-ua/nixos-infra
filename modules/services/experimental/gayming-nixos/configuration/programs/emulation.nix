{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    eden
    # Ryubing Canary is required to boot ACNH 3.0+ update atm
    # TODO: switch back to nixpkgs version once the fix drops in stable
    # ryubing
    (appimageTools.wrapType2 rec {
      pname = "ryujinx";
      version = "1.3.265";
      src = fetchurl {
        url = "https://git.ryujinx.app/api/v4/projects/68/packages/generic/Ryubing-Canary/${version}/ryujinx-canary-${version}-x64.AppImage";
        hash = "sha256-jNEGYNKp9/1UdJMdNHb666I7fnAMl0aIo4m/FwANjqM=";
      };
      extraPkgs =
        pkgs: with pkgs; [
          icu
        ];
    })
    steam-rom-manager
  ];
  gayming.labwc-headless.menuItems = [
    {
      label = "[switch] Eden";
      command = "eden";
    }
    {
      label = "[switch] Ryujinx";
      command = "ryujinx";
    }
    {
      label = "Steam ROM Manager";
      command = "steam-rom-manager";
    }
  ];

}
