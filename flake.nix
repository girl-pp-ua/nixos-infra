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
    nextcloud-testumgebung = {
      url = "github:onny/nixos-nextcloud-testumgebung";
      flake = false; # (importing single file)
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    redlib = {
      url = "github:redlib-org/redlib";
      flake = false; # (using as source for pkgs.redlib)
    };

    secrets = {
      url = "git+file:./submodules/secrets";
      flake = false;
    };
    devlootbox = {
      url = "git+file:./submodules/devlootbox";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      deploy-rs,
      dns,
      sops-nix,
      secrets,
      ...
    }:
    let
      hostSystem = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${hostSystem};
      specialArgs = {
        root = ./.;
        libx = import ./lib { };
        secrets = import "${secrets}/plaintext.nix";
        system = hostSystem;
        inherit
          self
          inputs
          dns
          ;
      };
      mkNixosSystem =
        host: targetSystem: extraModules:
        (nixpkgs.lib.nixosSystem {
          system = targetSystem;
          specialArgs = specialArgs // {
            inherit host;
          };
          modules = [
            { networking.hostName = host; }
            ./hosts/${host}/configuration.nix
            ./modules/base
            ./modules/services
            sops-nix.nixosModules.sops
          ]
          ++ extraModules;
        });
      mkDeployProfile = hostname: configuration: {
        inherit hostname;
        sshUser = "nixos";
        user = "root";
        profiles.system.path = deploy-rs.lib.${hostSystem}.activate.nixos configuration;
      };
    in
    {
      nixosConfigurations = {
        oci1 = mkNixosSystem "oci1" "x86_64-linux" [
          {
            networking.domain = "girl.pp.ua";
            cfg.services = {
              caddy.enable = true;
              caddy.endpoints = {
                file-server.enable = true;
                healthcheck.enable = true;
                webdav.enable = true;
                authtest.enable = true;
              };
              dns-server.enable = true;
              kanidm.enable = true;
              gatus.enable = true;
              garage.enable = true;
            };
          }
        ];
        oci2 = mkNixosSystem "oci2" "x86_64-linux" [
          {
            networking.domain = "girl.pp.ua";
            cfg.services = {
              caddy.enable = true;
              caddy.endpoints = {
                healthcheck.enable = true;
                proxies.enable = true; # rip cocoa
              };
              dns-server.enable = true;
              redlib.enable = true;
              ntfy.enable = true;
              projects.devlootbox.enable = true;
            };
          }
        ];
        dell-sv = mkNixosSystem "dell-sv" "x86_64-linux" [
          {
            networking.domain = "ts.nix-infra";
            cfg.services = {
              caddy.enable = true;
              dns-server = {
                enable = true;
                zones = [ "nix-infra" ];
              };
              nextcloud.enable = true;
              paperless.enable = true;
            };
          }
        ];
      };

      # deploy-rs configuration
      deploy.nodes =
        let
          inherit (self) nixosConfigurations;
        in
        {
          oci1 = mkDeployProfile "oci1.girl.pp.ua" nixosConfigurations.oci1;
          oci2 = mkDeployProfile "oci2.girl.pp.ua" nixosConfigurations.oci2;
          dell-sv = mkDeployProfile "dell-sv.intranet.girl.pp.ua" nixosConfigurations.dell-sv;
        };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      # dev shells
      devShells.${hostSystem}.default = pkgs.mkShell {
        packages = [
          deploy-rs.outputs.packages.${hostSystem}.deploy-rs
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

      formatter.${hostSystem} = nixpkgs.legacyPackages.${hostSystem}.nixfmt-tree;
    };
}
