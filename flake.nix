{
  description = "NixOS configuration for nixos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-claude-code.url = "github:ryoppippi/nix-claude-code";
  };

  outputs = { nixpkgs, nix-flatpak, home-manager, nix-claude-code, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-flatpak.nixosModules.nix-flatpak
        home-manager.nixosModules.home-manager
        ./hosts/nixos/configuration.nix
        ./hosts/nixos/flatpak.nix
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
            users.ikd = import ./home/ikd.nix;
          };
        }
      ];
    };
  };
}
