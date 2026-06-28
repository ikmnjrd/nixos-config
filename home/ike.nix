{ inputs }:

let
  homeDirectory = "/home/ike";
in
{
  imports = [
    inputs.codex-desktop-linux.homeManagerModules.default
    (import ./base.nix {
      username = "ike";
      inherit homeDirectory;
    })
    (import ./wallpaper.nix {
      inherit homeDirectory;
      wallpaperFile = "surreal-cherry.jpg";
    })
  ];
}
