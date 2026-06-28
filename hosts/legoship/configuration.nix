{ lib, pkgs, ... }:

let
  gdmBackground = ../../assets/wallpapers/surreal-cherry.jpg;
in
{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
  ];

  networking.hostName = "legoship";

  nixpkgs.overlays = lib.mkAfter [
    (final: prev: {
      gnome-shell = prev.gnome-shell.overrideAttrs (oldAttrs: {
        postFixup = (oldAttrs.postFixup or "") + ''
          theme_resource="$out/share/gnome-shell/gnome-shell-theme.gresource"
          theme_dir="$(mktemp -d)"

          ${final.glib.dev}/bin/gresource list "$theme_resource" |
            while IFS= read -r resource_path; do
              file="''${resource_path#/org/gnome/shell/theme/}"
              ${final.glib.dev}/bin/gresource extract "$theme_resource" "$resource_path" > "$theme_dir/$file"
            done

          cp ${gdmBackground} "$theme_dir/gdm-background.jpg"

          for css in "$theme_dir"/gnome-shell-*.css; do
            cat >> "$css" <<'EOF'

#lockDialogGroup {
  background-image: url("resource:///org/gnome/shell/theme/gdm-background.jpg");
  background-size: cover;
  background-position: center;
  background-repeat: no-repeat;
}
EOF
          done

          {
            printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
            printf '%s\n' '<gresources>'
            printf '%s\n' '  <gresource prefix="/org/gnome/shell/theme">'
            find "$theme_dir" -maxdepth 1 -type f ! -name 'gnome-shell-theme.gresource.xml' -printf '    <file>%f</file>\n' | sort
            printf '%s\n' '  </gresource>'
            printf '%s\n' '</gresources>'
          } > "$theme_dir/gnome-shell-theme.gresource.xml"

          ${final.glib.dev}/bin/glib-compile-resources \
            --sourcedir="$theme_dir" \
            "$theme_dir/gnome-shell-theme.gresource.xml"
          cp "$theme_dir/gnome-shell-theme.gresource" "$theme_resource"
        '';
      });
    })
  ];

  programs.dconf.profiles.gdm.databases = [
    {
      lockAll = true;
      settings = {
        "org/gnome/desktop/background" = {
          picture-uri = "file://${gdmBackground}";
          picture-uri-dark = "file://${gdmBackground}";
          picture-options = "zoom";
          primary-color = "#2e3440";
          secondary-color = "#2e3440";
        };
        "org/gnome/desktop/screensaver" = {
          picture-uri = "file://${gdmBackground}";
          picture-options = "zoom";
          primary-color = "#2e3440";
          secondary-color = "#2e3440";
        };
      };
    }
  ];

  programs.steam.enable = true;

  services.flatpak.packages = [
    {
      appId = "com.discordapp.Discord";
      origin = "flathub";
    }
  ];

  environment.systemPackages = with pkgs; [
    google-chrome
    slack
  ];

  users.users.ike = {
    isNormalUser = true;
    description = "ike";
    extraGroups = [ "docker" "input" "keyd" "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };
}
