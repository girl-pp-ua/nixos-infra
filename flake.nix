{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, deploy-rs, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };
    specialArgs = {
      inherit self inputs system pkgs;
    };
    mkNixosSystem = host: extraModules: (
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = specialArgs // {
          inherit host;
        };
        modules = [
          { networking.hostName = host; }
          ./hosts/${host}/configuration.nix
          ./modules/base
        ] ++ extraModules;
      }
    );
  in {
    nixosConfigurations = {
      # oci1 = mkNixosSystem "oci1" [];
      oci2 = mkNixosSystem "oci2" [
        { cfg.ociAmdBase.isPastFirstBoot = true; }
        ./modules/role-services/healthcheck.nix
        ./modules/role-services/redlib.nix
      ];
    };

    # deploy-rs configuration
    deploy.nodes = {
      oci2 = {
        hostname = "oci2.girl.pp.ua";
        sshUser = "nixos";
        user = "root";
        profiles.system.path =
          deploy-rs.lib.${system}.activate.nixos
            self.nixosConfigurations.oci2;
      };
    };
    checks = builtins.mapAttrs
      (system: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;

    # dev shells
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        pkgs.deploy-rs
      ];
    };
  };
}