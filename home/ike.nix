let
  homeDirectory = "/home/ike";
in
{
  imports = [
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
