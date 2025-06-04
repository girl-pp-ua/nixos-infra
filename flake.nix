{
  inputs = {
    nixpkgs = {
      # url = "github:NixOS/nixpkgs/nixos-unstable-small";
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
      url = "github:louislam/uptime-kuma/2.0.0-beta.2";
      flake = false;
    };
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      deploy-rs,
      dns,
      sops-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      specialArgs = {
        inherit
          self
          inputs
          system
          dns
          ;
      };
      mkNixosSystem =
        host: extraModules:
        (nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = specialArgs // {
            inherit host;
          };
          modules = [
            { networking.hostName = host; }
            ./hosts/${host}/configuration.nix
            ./secrets-old/schema.nix
            ./secrets-old/credentials.nix
            ./modules/base
            sops-nix.nixosModules.sops
          ] ++ extraModules;
        });
      mkDeployProfile = hostname: host: {
        inherit hostname;
        sshUser = "nixos";
        user = "root";
        profiles.system.path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${host};
      };
    in
    {
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
              ntfy.enable = true;
            };
          }
        ];
        dell = mkNixosSystem "dell" [
          {
            cfg.services = {
              # TODO
            };
          }
        ];
      };

      # deploy-rs configuration
      deploy.nodes = {
        oci1 = mkDeployProfile "oci1.girl.pp.ua" "oci1";
        oci2 = mkDeployProfile "oci2.girl.pp.ua" "oci2";
        dell = mkDeployProfile "dell.saga-mirzam.ts.net" "dell";
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      # dev shells
      devShells.${system}.default = pkgs.mkShell {
        packages =
          [
            deploy-rs.outputs.packages.${system}.deploy-rs
          ]
          ++ (with pkgs; [
            nil
            nixd
            nixfmt-rfc-style
            nixfmt-tree
            sops
            age
            ssh-to-age
          ]);
        shellHook = ''
          export SOPS_AGE_KEY=$(ssh-to-age -i ~/.ssh/id_ed25519 -private-key)
        '';
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}
