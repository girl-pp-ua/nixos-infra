{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    # submodules:
    secrets = {
      url = "git+file:./submodules/secrets";
      flake = false;
    };
    devlootbox = {
      url = "git+file:./submodules/devlootbox";
    };

    nix-secrets = {
      url = "github:unnamed-systems/nix-secrets";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      # fork (with https://github.com/serokell/deploy-rs/pull/271 merged)
      url = "github:neunenak/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dns = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nextcloud-testumgebung = {
      url = "github:onny/nixos-nextcloud-testumgebung";
      flake = false;
    };
    nc4nix = {
      url = "github:helsinki-systems/nc4nix";
      flake = false;
      # url = "git+https://git.helsinki.tools/helsinki-systems/nc4nix.git/";
    };
  };

  outputs =
    inputs@{
      nixpkgs-stable,
      flake-parts,
      systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, inputs, ... }:
      let
        hosts = import ./data/hosts.nix;

        specialArgs = {
          root = ./.;
          libx = import ./lib { };
          secrets = import "${inputs.secrets}/plaintext.nix";
          inherit inputs;
        };
        mkNixosSystem =
          system: extraModules:
          (inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = specialArgs // {
              pkgs-stable = import nixpkgs-stable {
                inherit system;
              };
              inherit system;
            };
            modules = [
              ./modules
              inputs.nix-secrets.nixosModules.default
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
          oci1 = mkNixosSystem "x86_64-linux" [ ./hosts/oci1/configuration.nix ];
          oci2 = mkNixosSystem "x86_64-linux" [ ./hosts/oci2/configuration.nix ];
          dell-sv = mkNixosSystem "x86_64-linux" [ ./hosts/dell-sv/configuration.nix ];
          astra = mkNixosSystem "aarch64-linux" [ ./hosts/astra/configuration.nix ];
          amoeba = mkNixosSystem "x86_64-linux" [ ./hosts/amoeba/configuration.nix ];
        };

        flake.deploy.nodes = {
          oci1 = mkDeployNode {
            hostname = hosts.oci1.internal.ipv6;
            system = "x86_64-linux";
            configuration = self.nixosConfigurations.oci1;
          };
          oci2 = mkDeployNode {
            hostname = hosts.oci2.internal.ipv6;
            system = "x86_64-linux";
            configuration = self.nixosConfigurations.oci2;
          };
          dell-sv = mkDeployNode {
            hostname = hosts.dell-sv.internal.ipv6;
            system = "x86_64-linux";
            configuration = self.nixosConfigurations.dell-sv;
          };
          astra = mkDeployNode {
            hostname = hosts.astra.internal.ipv6;
            system = "aarch64-linux";
            configuration = self.nixosConfigurations.astra;
          };
          amoeba = mkDeployNode {
            hostname = hosts.amoeba.internal.ipv6;
            system = "x86_64-linux";
            configuration = self.nixosConfigurations.amoeba;
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
                (pkgs.writeShellScriptBin "nix-secrets" ''
                  exec ${inputs'.nix-secrets.packages.nix-secrets}/bin/nix-secrets \
                    -i "$HOME/.ssh/nixos_infra" "$@"
                '')
              ]
              ++ (with pkgs; [
                nil
                nixd
                nixfmt
                nixfmt-tree
                age
              ]);
              shellHook = ''
                export NIX_SECRETS_STORAGE_PATH="$PWD/submodules/secrets/storage"
              '';
            };
          };
      }
    );
}
