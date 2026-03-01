{ ... }:
{
  # HACK: wifi (not used rn anyway but this makes it work)
  networking.networkmanager.wifi.powersave = false;
  boot.extraModprobeConfig = ''
    options rtw88_core disable_lps_deep=y
    options rtw88_pci disable_msi=y disable_aspm=y
    options rtw_core disable_lps_deep=y
    options rtw_pci disable_msi=y disable_aspm=y
  '';
}
