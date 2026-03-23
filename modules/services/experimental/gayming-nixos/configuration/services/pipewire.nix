{ ... }:
{
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    audio.enable = true;
    pulse.enable = true;
    # systemWide = true;
  };
}
