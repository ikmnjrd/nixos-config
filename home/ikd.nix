{ inputs }:

{
  imports = [
    inputs.codex-desktop-linux.homeManagerModules.default
    (import ./base.nix {
      username = "ikd";
      homeDirectory = "/home/ikd";
    })
  ];
}
