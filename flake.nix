{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

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
    nextcloud-testumgebung = {
      url = "github:onny/nixos-nextcloud-testumgebung";
      flake = false;
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
      pkgs-stable = inputs.nixpkgs-stable.legacyPackages.${hostSystem};
      specialArgs = {
        root = ./.;
        libx = import ./lib { };
        secrets = import "${secrets}/plaintext.nix";
        system = hostSystem;
        inherit
          self
          inputs
          dns
          pkgs-stable
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
      mkDeployProfile = hostname: configuration: {
        inherit hostname;
        sshUser = "nixos";
        user = "root";
        profiles.system.path = deploy-rs.lib.${hostSystem}.activate.nixos configuration;
      };
    in
    {
      nixosConfigurations = {
        oci1 = mkNixosSystem "oci1" "x86_64-linux" [ ];
        oci2 = mkNixosSystem "oci2" "x86_64-linux" [ ];
        dell-sv = mkNixosSystem "dell-sv" "x86_64-linux" [ ];
      };

      # deploy-rs configuration
      deploy.nodes =
        let
          inherit (self) nixosConfigurations;
        in
        {
          oci1 = mkDeployProfile "ipv4.oci1.girl.pp.ua" nixosConfigurations.oci1;
          oci2 = mkDeployProfile "ipv4.oci2.girl.pp.ua" nixosConfigurations.oci2;
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
