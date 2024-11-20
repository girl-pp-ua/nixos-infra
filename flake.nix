{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; # small?
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    # disko = {
    #   url = "github:nix-community/disko";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };
  outputs = {
    nixpkgs,
    disko,
    nixos-facter-modules,
    ...
  }: {
    nixosConfigurations = let
      buildNixosSystem = system: name: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          nixos-facter-modules.nixosModules.facter
          { config.facter.reportPath = ./hosts/${name}/facter.json; }
          ./hosts/${name}/disko-config.nix
          ./configuration
        ];
      };
    in {
      oci2 = buildNixosSystem "x86_64-linux" "oci2";
    };
  };
}