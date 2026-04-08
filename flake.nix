{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      # fork with https://github.com/serokell/deploy-rs/pull/271 merged
      url = "github:neunenak/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dns = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # submodules:
    secrets = {
      url = "git+file:./submodules/secrets";
      flake = false;
    };
    devlootbox = {
      url = "git+file:./submodules/devlootbox";
    };

    # misc deps:
    # redlib = {
    #   url = "github:redlib-org/redlib";
    #   flake = false; # (using as source for pkgs.redlib)
    # };
    nextcloud-testumgebung = {
      url = "github:onny/nixos-nextcloud-testumgebung";
      flake = false;
    };
  };

  outputs =
    inputs@{
      flake-parts,
      systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, inputs, ... }:
      let
        specialArgs = {
          root = ./.;
          libx = import ./lib { };
          secrets = import "${inputs.secrets}/plaintext.nix";
          inherit inputs;
        };
        mkNixosSystem =
          host: targetSystem: extraModules:
          (inputs.nixpkgs.lib.nixosSystem {
            system = targetSystem;
            specialArgs = specialArgs // {
              system = targetSystem;
              inherit host;
            };
            modules = [
              {
                networking.hostName = host;
                networking.domain = "polaris";
              }
              inputs.sops-nix.nixosModules.sops
              ./hosts/${host}/configuration.nix
              ./modules
            ]
            ++ extraModules;
          });
        mkDeployNode =
          {
            hostname,
            configuration,
            system,
          }:
          {
            inherit hostname;
            sshUser = "nixos";
            user = "root";
            profiles.system.path = inputs.deploy-rs.lib.${system}.activate.nixos configuration;
          };
      in
      {
        systems = import systems;

        flake.nixosConfigurations = {
          oci1 = mkNixosSystem "oci1" "x86_64-linux" [ ];
          oci2 = mkNixosSystem "oci2" "x86_64-linux" [ ];
          dell-sv = mkNixosSystem "dell-sv" "x86_64-linux" [ ];
          astra = mkNixosSystem "astra" "aarch64-linux" [ ];
        };

        flake.deploy.nodes = {
          oci1 = mkDeployNode {
            hostname = "oci1.lunya.cc";
            system = "x86_64-linux";
            configuration = self.nixosConfigurations.oci1;
          };
          oci2 = mkDeployNode {
            hostname = "oci2.lunya.cc";
            system = "x86_64-linux";
            configuration = self.nixosConfigurations.oci2;
          };
          dell-sv = mkDeployNode {
            hostname = "dell-sv.intranet.girl.pp.ua";
            system = "x86_64-linux";
            configuration = self.nixosConfigurations.dell-sv;
          };
          astra = mkDeployNode {
            hostname = "astra.lunya.cc";
            system = "aarch64-linux";
            configuration = self.nixosConfigurations.astra;
          };
        };

        perSystem =
          {
            pkgs,
            inputs',
            system,
            ...
          }:
          {
            formatter = pkgs.nixfmt-tree;

            checks = inputs.deploy-rs.lib.${system}.deployChecks self.deploy;

            devShells.default = pkgs.mkShell {
              packages = [
                inputs'.deploy-rs.packages.deploy-rs
              ]
              ++ (with pkgs; [
                nil
                nixd
                nixfmt
                nixfmt-tree
                sops
                age
                ssh-to-age
              ]);
              shellHook = ''
                export SOPS_AGE_KEY=$(ssh-to-age -i ~/.ssh/id_ed25519 -private-key)
              '';
            };
          };
      }
    );
}
