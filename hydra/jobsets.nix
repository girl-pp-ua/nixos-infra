{ ... }:
let
  flakeJobset = flake: description: {
    enabled = 1;
    hidden = false;
    type = 1;
    inherit flake description;
    checkinterval = 300;
    schedulingshares = 100;
    enableemail = false;
    emailoverride = "";
    keepnr = 3;
    inputs = { };
  };

  jobsets = {
    build = flakeJobset "git+https://github.com/girl-pp-ua/nixos-infra?submodules=1" "master";

    # local clone bumped weekly by hydra-flake-update.service (modules/services/hydra.nix)
    flake-update =
      flakeJobset "git+file:///var/lib/hydra-flake-update/nixos-infra?ref=auto&submodules=1" "master with all inputs updated, rebuilt weekly"
      // {
        checkinterval = 3600;
        schedulingshares = 20;
        keepnr = 1;
      };
  };
in
{
  jobsets = derivation {
    name = "nixos-infra-jobsets.json";
    system = "x86_64-linux";
    builder = "/bin/sh";
    args = [
      "-c"
      ''printf '%s' "$spec" > "$out"''
    ];
    spec = builtins.toJSON jobsets;
  };
}
