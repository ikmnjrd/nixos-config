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
    claude-desktop.url = "github:aaddrick/claude-desktop-debian";
    # ywhispは一時的に無効化。
    # ywhisp.url = "path:/home/ike/workspace/ywhisp";
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
          ({ lib, pkgs, ... }: {
            home-manager.backupCommand = pkgs.writeShellScript "home-manager-backup" ''
              set -eu
              ${pkgs.coreutils}/bin/mv --backup=numbered -- "$1" "$1.hm-backup"
            '';
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
            # ywhispは一時的に無効化。
            # inputs.ywhisp.nixosModules.ywhisp
            home-manager.nixosModules.home-manager
            ./hosts/legoship/configuration.nix
            # ywhispは一時的に無効化。
            # {
            #   services.ywhisp = {
            #     enable = true;
            #     openFirewall = true;
            #     enableGnomeExtension = true;
            #     users = [ "ike" ];
            #
            #     certFile = "/home/ike/.config/ywhisp/certs/lan.pem";
            #     keyFile = "/home/ike/.config/ywhisp/certs/lan-key.pem";
            #     whisperModel = "/home/ike/.local/share/ywhisp/models/ggml-base.bin";
            #   };
            # }
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
