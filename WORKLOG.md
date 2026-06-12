# NixOS configuration worklog

Last updated: 2026-06-12 (Asia/Tokyo)

## Goal

Manage this machine's NixOS configuration from this repository, using a Flake
and a repeatable check/build/test/switch workflow. This repository is the source
of truth; `/etc/nixos` is only an emergency import source.

## Completed

- Copied the current `/etc/nixos/configuration.nix` and
  `/etc/nixos/hardware-configuration.nix` into `hosts/nixos/`.
- Added `flake.nix` with `nixosConfigurations.nixos`, using the NixOS 26.05
  nixpkgs branch.
- Generated `flake.lock`, pinned to nixpkgs revision
  `bd0ff2d3eac24699c3664d5966b9ef36f388e2ca` from 2026-06-08.
- Added `hosts/nixos/repository.nix` to:
  - install Git;
  - enable `nix-command` and `flakes`.
- Added `bin/nixos-config` with:
  - `sync-from-etc`
  - `check`
  - `build`
  - `test`
  - `switch`
- Added `.gitignore` and `README.md`.
- Initialized `.git` with the `main` branch.
- Did not create a commit because global Git identity is intentionally deferred.
- Successfully activated the Flake configuration on 2026-06-12.
- Confirmed:
  - Git 2.54.0 is available from `/run/current-system/sw/bin/git`;
  - `/etc/nix/nix.conf` enables `nix-command flakes`;
  - `sync-from-etc` initially reports no differences;
  - `result` and `result-*` are ignored;
  - `./bin/nixos-config check` passes;
  - `./bin/nixos-config build` succeeds.
- Updated the renamed GNOME and GDM options to their current NixOS names. This
  final warning cleanup was applied successfully.
- Confirmed the final `./bin/nixos-config check` succeeds without warnings.
- The current system path is
  `/nix/store/kch4yg0w55n3wlmklk01rxnkgs5xcz1s-nixos-system-nixos-26.05.20260608.bd0ff2d`.

## Initial activation note

The first activation has been completed. The following command is retained for
recovery or setup on a fresh installation:

The first activation must explicitly enable Flakes on the command line:

```sh
cd /home/ikd/workspace/nixos-config
sudo nixos-rebuild switch \
  --option experimental-features "nix-command flakes" \
  --flake "path:$PWD#nixos"
```

This installs Git and persists the experimental feature settings.

An earlier attempt used `--extra-experimental-features`, but this installed
`nixos-rebuild` rejected that Nix global argument. Use the supported `--option`
form shown above.

## Resume checklist

For the next session:

```sh
cd /home/ikd/workspace/nixos-config
hash -r
git --version
nix flake metadata path:.
git add .
git status --short --branch
./bin/nixos-config check
./bin/nixos-config build
./bin/nixos-config switch
```

Then configure the global Git identity before the first commit:

```sh
git config --global user.name "<name>"
git config --global user.email "<email>"
git commit -m "Initialize NixOS configuration"
```

Do not add a GitHub remote until its destination has been decided.

## Remaining verification

- Continue adding the desired NixOS and home configuration.

## Notes

- `configuration.bak.nix` is intentionally not managed.
- `hosts/nixos/repository.nix` is separate so an emergency
  `sync-from-etc` cannot remove Git or Flake support.
- `/etc/nixos` is not rewritten by a Flake switch. Differences are expected
  after repository changes. Only accept `sync-from-etc` when `/etc/nixos`
  intentionally contains a newer emergency fix.
- `hosts/nixos/hardware-configuration.nix` describes this machine and should
  normally not be edited manually.

## Pending Git configuration change

On 2026-06-12, the latest `.gitconfig` from
`https://github.com/ikmnjrd/dotfiles` was added as `home/.gitconfig`.

`hosts/nixos/repository.nix` now:

- creates `/home/ikd/.gitconfig` as a managed symlink;
- installs `git-lfs`, `gh`, and `neovim`, which the imported configuration
  references.

Before asking the user to switch, run:

```sh
./bin/nixos-config check
./bin/nixos-config build
git add .
git diff --cached --check
```

After the user runs `./bin/nixos-config switch`, verify:

```sh
readlink -f /home/ikd/.gitconfig
git config --global --get user.name
git config --global --get user.email
git config --global --get core.editor
git lfs version
gh --version
nvim --version
```

## GitHub connection

The Git configuration was applied and the initial commit was created:

```text
24f073f init
```

Current state:

- no Git remote is configured;
- `/home/ikd/.ssh` contains no key or SSH config;
- `gh auth status` reports no authenticated GitHub host;
- Git identity is `ike <40803799+ikmnjrd@users.noreply.github.com>`.

Authenticate interactively with GitHub and let GitHub CLI create/register an
SSH key:

```sh
gh auth login --hostname github.com --git-protocol ssh --web
```

Authentication credentials and the private SSH key must remain outside this
repository. Do not add them to Nix configuration or Git.

After authentication, verify:

```sh
gh auth status
ssh -T git@github.com
```

Then decide the repository name and visibility before running `gh repo create`
or adding an existing repository as `origin`.

GitHub connectivity was completed and verified on 2026-06-12:

- GitHub CLI account: `ikmnjrd`;
- Git protocol: SSH;
- `ssh -T git@github.com` authenticated successfully;
- remote: `git@github.com:ikmnjrd/nixos-config.git`;
- repository: `https://github.com/ikmnjrd/nixos-config`;
- visibility: public;
- local `main` and `origin/main` were synchronized at commit `24f073f`.
