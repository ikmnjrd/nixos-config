# nixos-config

This repository is the source of truth for the NixOS host named `nixos`.
The configuration uses a flake pinned to the NixOS 26.05 branch.

## First setup

The repository starts from the current files in `/etc/nixos`. Repository tooling
is kept separately in `hosts/nixos/repository.nix`, so importing an emergency
edit does not remove Git or Flake support. Before the first switch, review the
configuration and run:

```sh
./bin/nixos-config check
./bin/nixos-config build
sudo nixos-rebuild switch \
  --option experimental-features "nix-command flakes" \
  --flake "path:$PWD#nixos"
```

The repository is already initialized with `main` as its default branch. The
first switch installs Git and enables `nix-command` and `flakes` persistently.
Set your global Git identity before making the first commit.

## Daily workflow

Edit files under `hosts/nixos`, then validate and activate them:

```sh
./bin/nixos-config check
./bin/nixos-config build
./bin/nixos-config test
./bin/nixos-config switch
```

`test` activates the configuration without changing the boot default. Use
`switch` after confirming the system works.

If `/etc/nixos` was edited directly in an emergency, import only the two managed
files after reviewing the displayed diff:

```sh
./bin/nixos-config sync-from-etc
```

Do not use `/etc/nixos` as the normal editing location.
`configuration.bak.nix` is intentionally not managed.
After repository-only changes, differences from `/etc/nixos` are expected.
Do not accept `sync-from-etc` unless `/etc/nixos` intentionally contains a
newer emergency fix; otherwise it would restore stale settings.

## Rollback

List and activate previous generations with:

```sh
sudo nixos-rebuild list-generations
sudo nixos-rebuild switch --rollback
```

`hosts/nixos/hardware-configuration.nix` is tracked because it describes this
machine's disks and hardware, but it should not normally be edited by hand.

## Git configuration

`home/.gitconfig` is imported from
`https://github.com/ikmnjrd/dotfiles/blob/main/.gitconfig`. A NixOS switch
creates `/home/ikd/.gitconfig` as a managed symlink to the Nix store. Git LFS,
GitHub CLI, and Neovim are installed because the configuration references them.
