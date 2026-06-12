# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

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
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Tokyo";

  # Select internationalisation properties.
  i18n.defaultLocale = "ja_JP.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  # Japanese input method: Fcitx5 + Mozc.
  # Do not add plain `fcitx5` to environment.systemPackages;
  # the NixOS module builds the patched fcitx5-with-addons wrapper.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-mozc
        fcitx5-gtk
      ];
    };
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Keep the display on for 30 minutes and suspend after 60 minutes of
  # inactivity, both on AC power and battery.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/session" = {
          idle-delay = lib.gvariant.mkUint32 1800;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-timeout = lib.gvariant.mkInt32 3600;
          sleep-inactive-ac-type = "suspend";
          sleep-inactive-battery-timeout = lib.gvariant.mkInt32 3600;
          sleep-inactive-battery-type = "suspend";
        };
      };
    }
  ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;

  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # My first customize
  xdg.portal.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."ikd" = {
    isNormalUser = true;
    description = "ikd";
    extraGroups = [ "networkmanager" "wheel" ];
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

  # Install firefox.
  programs.firefox.enable = true;

  # Register Zsh as a valid login shell. User configuration is managed by
  # Home Manager.
  programs.zsh.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    kdePackages.fcitx5-configtool
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
