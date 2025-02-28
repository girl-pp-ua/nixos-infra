{
  inputs = {
    nixpkgs = {
      # url = "github:NixOS/nixpkgs/nixos-unstable-small";
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    deploy-rs = {
      url = "github:PhilTaken/deploy-rs/phil/async-build-and-push";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dns = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    redlib = {
      url = "github:redlib-org/redlib";
      flake = false; # (using as source for pkgs.redlib)
    };
    uptime-kuma = {
      url = "github:louislam/uptime-kuma/2.0.0-beta.1";
      flake = false;
    };
  };
  outputs = inputs@{ self, nixpkgs, deploy-rs, dns, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    specialArgs = {
      inherit self inputs system dns;
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
            file-server-endpoint.enable = true;
            webdav-endpoint.enable = true;
            kanidm.enable = true;
            uptime-kuma.enable = true;
          };
        }
      ];
      oci2 = mkNixosSystem "oci2" [
        {
          cfg.services = {
            dns-server.enable = true;
            redlib.enable = true;
            # nitter.enable = true; # TODO fix; borked
            ntfy.enable = true;
            # testing.asterisk.enable = true;
          };
        }
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
        deploy-rs.outputs.packages.${system}.deploy-rs
        git-crypt
      ];
    };
  };
}