{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = { nixpkgs, ... }: {
    nixosConfigurations = let
      buildNixosSystem = system: name: extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${name}/configuration.nix
          ./modules/base
        ] ++ extraModules;
      };
    in {
      # oci1 = buildNixosSystem "x86_64-linux" "oci1" [];
      oci2 = buildNixosSystem "x86_64-linux" "oci2" [
        ./modules/role-services/redlib.nix
      ];
    };
  };
}