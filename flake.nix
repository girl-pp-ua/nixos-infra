{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; # small?
    # nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    # disko = {
    #   url = "github:nix-community/disko";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };
  outputs = { nixpkgs, ... }: {
    nixosConfigurations = let
      buildNixosSystem = system: name: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${name}/hardware-configuration.nix
          ./hosts/${name}/configuration.nix
          ./modules/base.nix
        ];
      };
    in {
      oci2 = buildNixosSystem "x86_64-linux" "oci2";
    };
  };
}