{ lib, pkgs, ... }:

let
  authorizedKeys = import ./remote-dev-keys.nix;

  remoteDevHelper = pkgs.writeShellApplication {
    name = "remote-dev-helper";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      curl
      docker
      docker-compose
      findutils
      gnugrep
      gawk
      iproute2
      jq
      nix
      systemd
      util-linux
    ];
    text = builtins.readFile ./remote-dev-helper.sh;
  };
in
{
  users.users.ikd = {
    linger = true;
    openssh.authorizedKeys.keys = authorizedKeys;
  };

  environment.systemPackages = [
    pkgs.docker-compose
    pkgs.jq
    remoteDevHelper
  ];

  services.avahi = {
    enable = true;
    openFirewall = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = authorizedKeys == [ ];
    KbdInteractiveAuthentication = authorizedKeys == [ ];
  };

  warnings = lib.optional (authorizedKeys == [ ])
    "remote-dev SSH keys are empty; password authentication remains enabled";

  systemd.tmpfiles.rules = [
    "d /home/ikd/workspace/remote-dev 0755 ikd users -"
    "d /home/ikd/.local/state/remote-dev 0700 ikd users -"
    "d /home/ikd/.local/state/remote-dev/slots 0700 ikd users -"
  ];
}
