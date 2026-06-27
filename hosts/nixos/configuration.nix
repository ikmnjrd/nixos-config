# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, ... }:

let
  gtkBookmarks = pkgs.writeText "gtk-bookmarks" ''
    file:///home/ikd/Documents
    file:///home/ikd/Music
    file:///home/ikd/Pictures
    file:///home/ikd/Videos
    file:///home/ikd/Downloads
  '';
  userDirs = pkgs.writeText "user-dirs.dirs" ''
    XDG_DESKTOP_DIR="$HOME/Desktop"
    XDG_DOWNLOAD_DIR="$HOME/Downloads"
    XDG_TEMPLATES_DIR="$HOME/Templates"
    XDG_PUBLICSHARE_DIR="$HOME/Public"
    XDG_DOCUMENTS_DIR="$HOME/Documents"
    XDG_MUSIC_DIR="$HOME/Music"
    XDG_PICTURES_DIR="$HOME/Pictures"
    XDG_VIDEOS_DIR="$HOME/Videos"
    XDG_PROJECTS_DIR="$HOME/Projects"
  '';
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../common/configuration.nix
      ./remote-dev.nix
    ];

  networking.hostName = "nixos"; # Define your hostname.

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."ikd" = {
    isNormalUser = true;
    description = "ikd";
    extraGroups = [ "docker" "keyd" "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };

  # Use English XDG user directory names regardless of the system locale.
  systemd.tmpfiles.rules = [
    "d /home/ikd/Desktop 0755 ikd users -"
    "d /home/ikd/Documents 0755 ikd users -"
    "d /home/ikd/Downloads 0755 ikd users -"
    "d /home/ikd/Music 0755 ikd users -"
    "d /home/ikd/Pictures 0755 ikd users -"
    "d /home/ikd/Projects 0755 ikd users -"
    "d /home/ikd/Public 0755 ikd users -"
    "d /home/ikd/Templates 0755 ikd users -"
    "d /home/ikd/Videos 0755 ikd users -"
    "d /home/ikd/workspace 0755 ikd users -"
    "d /home/ikd/.config 0755 ikd users -"
    "d /home/ikd/.config/gtk-3.0 0755 ikd users -"
    "L+ /home/ikd/.config/gtk-3.0/bookmarks - - - - ${gtkBookmarks}"
    "L+ /home/ikd/.config/user-dirs.dirs - - - - ${userDirs}"
    "r /home/ikd/デスクトップ - - - - -"
    "r /home/ikd/ダウンロード - - - - -"
    "r /home/ikd/テンプレート - - - - -"
    "r /home/ikd/公開 - - - - -"
    "r /home/ikd/ドキュメント - - - - -"
    "r /home/ikd/音楽 - - - - -"
    "r /home/ikd/画像 - - - - -"
    "r /home/ikd/ビデオ - - - - -"
    "r /home/ikd/プロジェクト - - - - -"
  ];

}
