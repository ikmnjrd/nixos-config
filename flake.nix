{
  description = "NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-claude-code.url = "github:ryoppippi/nix-claude-code";
  };

  outputs = { nixpkgs, nix-flatpak, home-manager, nix-claude-code, ... }:
    let
      system = "x86_64-linux";

      subPc = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
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
                  "claude"
                ];
              overlays = [ nix-claude-code.overlays.default ];
            };
          })
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              users.ikd = import ./home/ikd.nix {};
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
            nix-flatpak.nixosModules.nix-flatpak
            home-manager.nixosModules.home-manager
            ./hosts/legoship/configuration.nix
            {
              nixpkgs.overlays = [ nix-claude-code.overlays.default ];
            }
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                users.ike = import ./home/ike.nix;
              };
            }
          ];
        };

        nixos = subPc;
      };
    };
}
