{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
            system = targetSystem;
            inherit host;
          };
          modules = [
            {
              networking.hostName = host;
              networking.domain = "polaris";
            }
            ./hosts/${host}/configuration.nix
            ./modules
            sops-nix.nixosModules.sops
          ]
          ++ extraModules;
        });
      mkDeployProfile = hostname: configuration: targetSystem: {
        inherit hostname;
        sshUser = "nixos";
        user = "root";
        profiles.system.path = deploy-rs.lib.${targetSystem}.activate.nixos configuration;
      };
    in
    {
      nixosConfigurations = {
        oci1 = mkNixosSystem "oci1" "x86_64-linux" [ ];
        oci2 = mkNixosSystem "oci2" "x86_64-linux" [ ];
        dell-sv = mkNixosSystem "dell-sv" "x86_64-linux" [ ];
        astra = mkNixosSystem "astra" "aarch64-linux" [ ];
      };

      # deploy-rs configuration
      deploy.nodes =
        let
          inherit (self) nixosConfigurations;
        in
        {
          oci1 = mkDeployProfile "oci1.lunya.cc" nixosConfigurations.oci1 "x86_64-linux";
          oci2 = mkDeployProfile "oci2.lunya.cc" nixosConfigurations.oci2 "x86_64-linux";
          dell-sv = mkDeployProfile "dell-sv.intranet.girl.pp.ua" nixosConfigurations.dell-sv "x86_64-linux";
          astra = mkDeployProfile "astra.lunya.cc" nixosConfigurations.astra "aarch64-linux";
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

      formatter.${hostSystem} = nixpkgs.legacyPackages.${hostSystem}.nixfmt-tree;
    };
}
