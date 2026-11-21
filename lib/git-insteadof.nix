tokens:
let
  urls = builtins.attrNames tokens;
  entry =
    i:
    let
      url = builtins.elemAt urls i;
    in
    ''
      GIT_CONFIG_KEY_${toString i}=url.https://x-access-token:${tokens.${url}}@${builtins.substring 8 (-1) url}.insteadOf
      GIT_CONFIG_VALUE_${toString i}=${url}
    '';
in
builtins.concatStringsSep "" (builtins.genList entry (builtins.length urls))
+ "GIT_CONFIG_COUNT=${toString (builtins.length urls)}\n"
