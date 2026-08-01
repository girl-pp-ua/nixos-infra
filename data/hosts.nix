{
  # oci1: Oracle Cloud Infrastructure (Frankfurt) - VM.Standard.E2.1.Micro
  oci1 = {
    public = {
      fqdn = "oci1.lunya.cc";
      ipv4 = "132.226.204.218";
      ipv6 = "2603:c020:800c:9c7f:0:fe:fe:2";
    };
    internal = {
      fqdn = "oci1.polaris";
      ipv4 = "100.64.0.101";
      ipv6 = "fd7a:115c:a1e0::2a01:371";
    };
  };

  # oci2: Oracle Cloud Infrastructure (Frankfurt) - VM.Standard.E2.1.Micro
  oci2 = {
    public = {
      fqdn = "oci2.lunya.cc";
      ipv4 = "144.24.178.67";
      ipv6 = "2603:c020:800c:9c7f:0:ba:be:2";
    };
    internal = {
      fqdn = "oci2.polaris";
      ipv4 = "100.64.0.102";
      ipv6 = "fd7a:115c:a1e0::2501:5a59";
    };
  };

  # oci-loadbalancer: Oracle Cloud Infrastructure - test-loadbalancer
  # oci-loadbalancer = {
  #   public = {
  #     ipv4 = "130.61.214.159";
  #     ipv6 = "2603:c020:800c:9c7f:3906:822b:23d9:899c";
  #   };
  # };

  # (intranet) dell-sv; tailscale ips
  dell-sv = {
    internal = {
      fqdn = "dell-sv.polaris";
      ipv4 = "100.64.0.2";
      ipv6 = "fd7a:115c:a1e0::2901:2214";
    };
  };

  astra = {
    public = {
      fqdn = "astra.lunya.cc";
      ipv4 = "130.61.27.226";
      ipv6 = "2603:c020:800c:9c7f:0:d372:6d52:818c";
    };
    internal = {
      fqdn = "astra.polaris";
      ipv4 = "100.64.0.103";
      ipv6 = "fd7a:115c:a1e0::a738:aa73";
    };
  };

  amoeba = {
    public = {
      ipv4 = "152.53.95.222";
      ipv6 = "2a0a:4cc0:80:54d9::1";
    };
    internal = {
      ipv4 = "100.98.239.0";
      ipv6 = "fd7a:115c:a1e0::7238:ef01";
    };
  };
}
