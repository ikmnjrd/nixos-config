{
  description = "NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";
  };

  outputs = inputs@{ nixpkgs, nix-flatpak, home-manager, stylix, ... }:
    let
      system = "x86_64-linux";

      subPc = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          stylix.nixosModules.stylix
          nix-flatpak.nixosModules.nix-flatpak
          home-manager.nixosModules.home-manager
          ./hosts/nixos/configuration.nix
          ./hosts/nixos/repository.nix
          ({ lib, ... }: {
            nixpkgs = {
              config.allowUnfreePredicate = pkg:
                builtins.elem (lib.getName pkg) [
                  "1password"
                  "1password-cli"
                ];
            };
          })
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              users.ikd = import ./home/ikd.nix { inherit inputs; };
            };
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        legoship = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            stylix.nixosModules.stylix
            nix-flatpak.nixosModules.nix-flatpak
            home-manager.nixosModules.home-manager
            ./hosts/legoship/configuration.nix
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                users.ike = import ./home/ike.nix { inherit inputs; };
              };
            }
          ];
        };

        nixos = subPc;
      };
    };
}
