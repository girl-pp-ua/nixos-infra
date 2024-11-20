{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = { nixpkgs, ... }: {
    nixosConfigurations = let
      buildNixosSystem = system: name: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${name}/configuration.nix
          ./modules/base.nix
        ];
      };
    in {
      # oci1 = buildNixosSystem "x86_64-linux" "oci1";
      oci2 = buildNixosSystem "x86_64-linux" "oci2";
    };
  };
}