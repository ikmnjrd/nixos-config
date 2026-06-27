{
  homeDirectory,
  wallpaperFile,
}:

let
  wallpaper = "${homeDirectory}/Pictures/wallpapers/${wallpaperFile}";
in
{
  dconf.settings."org/gnome/desktop/background" = {
    picture-uri = "file://${wallpaper}";
    picture-uri-dark = "file://${wallpaper}";
    picture-options = "zoom";
    primary-color = "#2e3440";
    secondary-color = "#2e3440";
  };
}
