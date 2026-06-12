{ pkgs, ... }:

{
  # Tools and Nix features required to manage this repository.
  environment.systemPackages = [
    pkgs.git
    pkgs.git-lfs
    pkgs.gh
    pkgs.neovim
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  systemd.tmpfiles.rules = [
    "L+ /home/ikd/.gitconfig - - - - ${../../home/.gitconfig}"
  ];
}
