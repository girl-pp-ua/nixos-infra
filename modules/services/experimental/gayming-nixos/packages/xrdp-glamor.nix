{
  xrdp,
  libgbm,
}:
let
  xorgxrdp = xrdp.xorgxrdp.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ libgbm ];
    configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-glamor" ];
  });
in
xrdp.overrideAttrs (old: {
  postInstall = builtins.replaceStrings [ "${xrdp.xorgxrdp}" ] [ "${xorgxrdp}" ] old.postInstall;
  passthru = old.passthru // {
    inherit xorgxrdp;
  };
})
