{ config, lib, pkgs, ... }:

{
  imports = [
    ./flatpak.nix
    ./stylix.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tokyo";

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

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/session" = {
          idle-delay = lib.gvariant.mkUint32 1800;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-timeout = lib.gvariant.mkInt32 0;
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-battery-timeout = lib.gvariant.mkInt32 3600;
          sleep-inactive-battery-type = "suspend";
        };
      };
    }
  ];

  # Claude Codeのネイティブインストーラ版が配布する動的リンク済み実行ファイル用。
  programs.nix-ld = {
    enable = true;

    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      curl
      sqlite
    ];
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        leftmeta = "overload(meta, f14)";
        rightmeta = "overload(meta, f15)";
      };
    };
  };
  users.groups.keyd = {};
  systemd.services.keyd.serviceConfig.CapabilityBoundingSet = lib.mkForce [
    "CAP_IPC_LOCK"
    "CAP_SETGID"
    "CAP_SYS_NICE"
  ];
  systemd.services.keyd.serviceConfig.SystemCallFilter = lib.mkForce [
    "@system-service"
    "nice"
  ];

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  xdg.portal.enable = true;

  virtualisation.docker.enable = true;

  programs.firefox.enable = true;
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "ike" "ikd" ];
  };
  programs.zsh.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    curl
    fd
    gh
    git
    gnomeExtensions.kimpanel
    jq
    kdePackages.fcitx5-configtool
    ripgrep
    tree
    vim
    wget
  ];

  services.openssh.enable = true;

  system.stateVersion = "26.05";
}
