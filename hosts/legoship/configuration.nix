{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/configuration.nix
  ];

  networking.hostName = "legoship";

  users.users.ike = {
    isNormalUser = true;
    description = "ike";
    extraGroups = [ "docker" "keyd" "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };
}
