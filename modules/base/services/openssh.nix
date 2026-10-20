{ lib, config, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = true;
    # only declarative keys, ignore ~/.ssh/authorized_keys
    authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    knownHosts = builtins.mapAttrs (n: v: {
      hostNames =
        [ ]
        ++ (lib.optional (v ? public.fqdn) v.public.fqdn)
        ++ (lib.optional (v ? internal.fqdn) v.internal.fqdn)
        ++ (lib.optional (v ? public.ipv4) "[${v.public.ipv4}]")
        ++ (lib.optional (v ? public.ipv6) "[${v.public.ipv6}]")
        ++ (lib.optional (v ? internal.ipv4) "[${v.internal.ipv4}]")
        ++ (lib.optional (v ? internal.ipv6) "[${v.internal.ipv6}]")
        ++ (lib.optional (v ? public.ipv4) "${v.public.ipv4}")
        ++ (lib.optional (v ? public.ipv6) "${v.public.ipv6}")
        ++ (lib.optional (v ? internal.ipv4) "${v.internal.ipv4}")
        ++ (lib.optional (v ? internal.ipv6) "${v.internal.ipv6}");
      publicKey = v.hostKey;
    }) (lib.filterAttrs (n: v: v ? hostKey) config.polaris.hosts);
  };
}
