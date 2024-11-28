{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dns = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, deploy-rs, dns, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };
    specialArgs = {
      inherit self inputs system pkgs dns;
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
          ./secrets/schema.nix
          ./secrets/credentials.nix
          ./modules/base
        ] ++ extraModules;
      }
    );
    mkDeployProfile = hostname: host: {
      inherit hostname;
      sshUser = "nixos";
      user = "root";
      profiles.system.path =
        deploy-rs.lib.${system}.activate.nixos
          self.nixosConfigurations.${host};
    };
  in {
    nixosConfigurations = {
      oci1 = mkNixosSystem "oci1" [
        {
          cfg.services = {
            dns-server.enable = true;
          };
        }
        ./modules/role-services/healthcheck.nix
        ./modules/role-services/file-server.nix
      ];
      oci2 = mkNixosSystem "oci2" [
        {
          cfg.services = {
            dns-server.enable = true;
            redlib.enable = true;
            ntfy.enable = true;
          };
        }
        ./modules/role-services/healthcheck.nix
      ];
    };

    # deploy-rs configuration
    deploy.nodes = {
      oci1 = mkDeployProfile "oci1.girl.pp.ua" "oci1";
      oci2 = mkDeployProfile "oci2.girl.pp.ua" "oci2";
    };

    checks = builtins.mapAttrs
      (system: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;

    # dev shells
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        pkgs.deploy-rs
        git-crypt
      ];
    };
  };
}