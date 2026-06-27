{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
  ];

  networking.hostName = "legoship";

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
    extraGroups = [ "docker" "keyd" "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };
}
