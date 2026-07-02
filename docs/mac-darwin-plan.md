# Mac (nix-darwin) 対応 指示書

このリポジトリに Mac 用の構成と配備コマンドを追加し、~/workspace/dotfiles を
廃止できる状態にするための作業指示書。2026-07-02 の相談で決定した内容に基づく。

## 背景と決定事項

- このリポジトリは dotfiles から派生し、現在はこちらが本流(特に nvim 設定)。
- Linux はすべて NixOS 化するため、dotfiles の Linux 向け配備は廃止する。
- Mac は **nix-darwin** で本リポジトリから管理する(決定済み)。
- **yabai / skhd はもう使っていないため移植しない**。
- 対象 Mac は `ikembp`(ユーザー `ike`)と推定
  (`hosts/nixos/remote-dev-keys.nix` の `ike@ikembp.local` より)。

## 着手時にユーザーへ確認すること

以下は相談時に確認できなかった前提。作業開始時に確認し、違っていれば読み替える。

1. **アーキテクチャ**: Apple Silicon (`aarch64-darwin`) を前提とする。
   Intel なら `x86_64-darwin` に読み替え。
2. **ホスト名 / ユーザー名**: `ikembp` / `ike` を前提とする。
   Mac 上で `scutil --get LocalHostName` と `whoami` で確認。
3. **ターミナル**: WezTerm を前提とする(dotfiles に `.wezterm.lua` があり
   nix 管理しやすいため)。foot は Linux 専用なので Mac では使えない。
4. **GUI アプリ**: nix-darwin の `homebrew` モジュールで宣言管理する前提。
   Brewfile の cask のうち現役のものをユーザーに選んでもらう
   (yabai / skhd / iterm2 / tweeten あたりは廃止候補)。

## ゴール(完了条件)

- Mac 上で `./bin/darwin-config switch` 一発でユーザー環境が揃う。
- nvim(プラグイン込み)・zsh・tmux・git・espanso・VSCode 設定・
  remote-dev クライアントが Mac に適用される。
- Linux 側(legoship / nixos)の挙動は変わらない。
- dotfiles リポジトリは Mac でも参照不要になる。

## 進め方の原則

- AGENTS.md に従う: コメントは日本語、sudo が必要な switch は実行せず
  ユーザーに依頼する、特に言及がなければ ike / ikd 両環境へ変更する。
- Phase 1〜2 は Linux 上で完結できる。Phase 3 以降の実機確認は Mac が必要。
- 各 Phase の終わりで `./bin/nixos-config check` と `build` を通し、
  Linux 側にリグレッションがないことを確認してから次へ進む。

---

## Phase 1: home/base.nix を common / linux に分割する

現在 `home/base.nix`(約 700 行)に汎用設定と Linux 専用設定が混在している。
これを次の 2 ファイルに分割し、`base.nix` は削除する。

- `home/common.nix` — クロスプラットフォームで使うもの。
  引数 `{ username, homeDirectory }` の形は base.nix を踏襲する
  (Mac では `homeDirectory = "/Users/ike"` を渡すため、
  デフォルト `/home/${username}` のままでよい)。
- `home/linux.nix` — Linux(Wayland / GNOME / systemd)専用。

`home/ike.nix` と `home/ikd.nix` は common + linux を import する形に書き換える。

### 分類表

| base.nix の項目 | 行き先 | 備考 |
| --- | --- | --- |
| `codexCli` ラッパー | common | パス `~/.codex/...` は Mac でも同じ |
| `espansoWlPaste` / `espansoWayland` | linux | Wayland 専用ワークアラウンド |
| `textEditorMimeTypes` / `openInNvim` / `xdg.desktopEntries` / `xdg.mimeApps` | linux | foot と xdg に依存。tmux 連携部分を Mac でも使いたければ後続 Phase で WezTerm フォールバック版を検討(初回スコープ外) |
| `home.sessionPath` (`~/.local/bin`) | common | |
| `sessionVariables.DENO_NO_UPDATE_CHECK` | common | |
| `sessionVariables.QT_IM_MODULE(S)` | linux | fcitx 用 |
| `home.packages` | common | ただし `wl-clipboard` のみ linux へ |
| `.gitconfig` / `git/ignore` | common | |
| VSCode settings/keybindings | common(source 指定は共通化) | 配置先が異なる: Linux は `.config/Code/User/`、Mac は `Library/Application Support/Code/User/`。配置は各プラットフォームモジュール側で行う |
| tmux `window-theme` / `apply-window-theme` / `.local/bin/bat` | common | OSC エスケープは WezTerm でも動く想定。Mac 実機で要確認 |
| `ai-tools-update` スクリプト | common | スクリプト自体は POSIX。定期実行だけ分ける(下記) |
| `systemd.user.{services,timers}.ai-tools-update` | linux | Mac では `launchd.agents.ai-tools-update`(`StartCalendarInterval` で daily)を mac モジュールに用意 |
| `dconf.settings` 一式 | linux | GNOME 専用 |
| `services.espanso` | common(有効化)+ linux(`package-wayland`) | home-manager 26.05 の espanso モジュールは darwin 対応済み(launchd)。`package-wayland = espansoWayland` の指定だけ linux へ。configs/matches の yml 群(`xdg.configFile."espanso/..."`)は common |
| gtk-3.0 bookmarks | linux | Nautilus 用 |
| `stylix.targets.neovim.enable = false` | linux | Mac 側に stylix モジュールを入れないため、common に置くと darwin 評価が落ちる |
| `programs.bat` / `direnv` / `fzf` / `home-manager` | common | |
| `programs.foot` | linux | |
| `programs.codexDesktopLinux` | linux | flake input 自体が Linux 専用。`inputs.codex-desktop-linux.homeManagerModules.default` の import も linux 側(または ike.nix / ikd.nix 側)に残す |
| `programs.neovim`(プラグイン・init.vim 込み) | common | ここが Mac 移行の主目的 |
| `programs.tmux` | common(基本)+ 分割 | 下記参照 |
| `programs.zsh` | common(基本)+ 分割 | 下記参照 |

### tmux の分割

`extraConfig` のうち fcitx5 依存部分だけ linux へ:

- `bind-key -n C-f/C-b run-shell ... fcitx5-remote -c ...` の 2 行 → linux。
  Mac 側は素直に `prefix = "C-f"` を活かすため、common では
  `set -g prefix None` にせず、linux 側で上書きする構成にする
  (`lib.mkForce`/`lib.mkAfter` の順序に注意。common の extraConfig と
  linux の追記が両方効くことを `build` 後の生成物で確認する)。
- 全角キーの複製バインド(`bind-key ！` 〜)は日本語 IME 全般の事象なので common。
- `window-active-style` などの色設定は common。

### zsh の分割

- `pbcopy = "wl-copy"` / `pbpaste = "wl-paste"` の alias → linux
  (Mac にはネイティブの pbcopy がある)。
- `FZF_CTRL_R_OPTS` 内の `wl-copy` → クリップボードコマンドを引数化するか、
  この export だけ各プラットフォームモジュールで定義する
  (Mac は `pbcopy`)。
- それ以外(alias、history、initContent の git-prompt / fbr / gcd /
  select_worktree)は common。

### 検証

```sh
./bin/nixos-config check
./bin/nixos-config build
NIXOS_CONFIG_HOST=nixos ./bin/nixos-config check
```

build 結果の homeConfiguration 生成物(tmux.conf、.zshrc 等)を分割前と
diff して意図しない差分がないことを確認する。switch はユーザーに依頼。

---

## Phase 2: dotfiles 残存資産の吸収

dotfiles の deploy.sh が配っているもののうち、まだこのリポジトリに無いものを
common / mac へ取り込む。Linux も dotfiles 廃止対象なので、Linux でも使うものは
common に入れる。

| dotfiles の資産 | 対応 |
| --- | --- |
| `ssh/config`, `ssh/config.d/nixos-remote-dev` | リポジトリに `home/ssh/` としてコピーし、common で `home.file` 配備。内容は現行と同一に保つ(remote-dev のサーバ側は既に `hosts/nixos/remote-dev.nix` にある。これはそのクライアント側) |
| `bin/remote-dev` | `home/bin/remote-dev` としてコピーし、common で `.local/bin/remote-dev` に配備 |
| `.wezterm.lua` | Mac 用に `home/wezterm.lua` としてコピーし、mac モジュールで `programs.wezterm`(または `home.file ".wezterm.lua"`)配備。フォントは SauceCodePro Nerd Font に合わせる |
| `.zshrc` / `.zshenv` / `.tmux.conf` / `.gitconfig` | home-manager 管理(Phase 1 の common)で置き換え済みのはず。取りこぼしがないか diff で確認(例: `.zshenv` の内容、`.zshrc` の `~/.deno/env` 読み込みなど) |
| espanso / vscode 設定 | 取り込み済み。dotfiles 側が古ければこちらを正とする |
| `.alacritty.*` / `.yabairc` / `.skhdrc` | 廃止。移植しない |
| `Brewfile` | Phase 3 の homebrew モジュールへ(現役の cask のみ) |
| `install-via-*.sh`(Arch/Flatpak 用) | 廃止。移植しない |

---

## Phase 3: flake に darwin 構成を追加する

### 3-1. flake input

```nix
nix-darwin = {
  url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

nixpkgs(26.05)とリリースブランチを揃えること。

### 3-2. ホスト構成 `hosts/ikembp/configuration.nix`

新規作成。最低限:

```nix
{ pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # homebrew モジュール等が対象とするユーザー。
  system.primaryUser = "ike";
  users.users.ike.home = "/Users/ike";

  fonts.packages = [ pkgs.nerd-fonts.sauce-code-pro ];

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap"; # 宣言外の formula/cask を消す。初回はユーザーと相談
    casks = [
      # Brewfile から現役のものだけをユーザー確認の上で列挙する。候補:
      # "1password" "brave-browser" "firefox" "wezterm" "spotify" "gyazo"
    ];
  };

  # nix-darwin の stateVersion(整数)。導入時点の最新値を darwin-rebuild の
  # 案内に従って設定する。
  system.stateVersion = 6;
}
```

注意:

- Homebrew 本体のインストールは nix-darwin の管理外。README の手順に含める。
- CLI ツールは Brewfile からではなく common の `home.packages` で賄う
  (bat, fd, gh, jq, ripgrep, tree, neovim, tmux, deno などは既に common にある。
  Brewfile にしかない mutagen / smug / tig / pastel などは必要か
  ユーザーに確認してから common か mac モジュールへ)。

### 3-3. home モジュール `home/ike-mac.nix`

```nix
{ inputs }:
{
  imports = [
    (import ./common.nix {
      username = "ike";
      homeDirectory = "/Users/ike";
    })
    ./mac.nix
  ];
}
```

`home/mac.nix` に置くもの:

- VSCode 設定の配置:
  `home.file."Library/Application Support/Code/User/settings.json".source = ./vscode/settings.json;`
  (keybindings.json も同様)
- zsh: `FZF_CTRL_R_OPTS` の pbcopy 版
- `launchd.agents.ai-tools-update`(daily 実行)
- WezTerm 設定(Phase 2 参照)
- espanso: common の `services.espanso` がそのまま darwin で launchd 起動する
  想定。**nixpkgs の espanso が darwin でビルドできない場合**は、mac では
  `services.espanso.enable = lib.mkForce false` にし、Homebrew cask
  `"espanso"` + `home.file "Library/Application Support/espanso/..."` で
  設定ファイルだけ配る方式に切り替える(espanso v2 の macOS 標準設定パス)。

### 3-4. flake output

```nix
darwinConfigurations = {
  ikembp = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      ./hosts/ikembp/configuration.nix
      inputs.home-manager.darwinModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "hm-backup";
          users.ike = import ./home/ike-mac.nix { inherit inputs; };
        };
      }
    ];
  };
};
```

`codex-desktop-linux` input はここでは import しない(Linux 専用)。

### 検証(Linux 上でできる範囲)

```sh
# 評価のみ。ビルドは Mac でしかできない。
nix --extra-experimental-features "nix-command flakes" eval \
  "path:$PWD#darwinConfigurations.ikembp.system.drvPath"
./bin/nixos-config check   # Linux 側が壊れていないこと
```

評価が Linux 専用パッケージ(foot 等)を darwin 向けに引いてエラーになったら、
分類漏れ(linux 行きの設定が common に残っている)を疑う。

---

## Phase 4: 配備コマンドと README

### 4-1. `bin/darwin-config`

`bin/nixos-config` と同型の bash スクリプトを新規作成する。

- ホストは `DARWIN_CONFIG_HOST`(デフォルト `ikembp`)。
- コマンド: `check`(flake 評価)/ `build`(`darwin-rebuild build --flake`)/
  `switch`(`sudo darwin-rebuild switch --flake "path:${root}#${host}"`)。
- 初回は darwin-rebuild が未導入なので bootstrap を用意:

```sh
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake "path:$PWD#ikembp"
```

### 4-2. README 追記

「Mac のセットアップ」節を追加する。内容:

1. Nix のインストール(公式マルチユーザーインストーラ。
   `nix-command flakes` を有効化)
2. Homebrew のインストール(cask 管理に必要)
3. `git clone` →(必要なら)`scutil --get LocalHostName` でホスト名確認
4. 初回 bootstrap switch(上記)、以降は `./bin/darwin-config switch`

### 4-3. AGENTS.md 更新

「両環境(ike/ikd)へ変更する」ルールに Mac(`ikembp`)を加えるか、
common/linux/mac の分割後の変更方針(common を触れば全環境に効く)を追記する。

---

## Phase 5: Mac 実機での確認と dotfiles 廃止

Mac 上で確認すること(ユーザーに依頼するか、Mac 上のセッションで実施):

- [ ] `./bin/darwin-config switch` が通る
- [ ] nvim が起動し、coc / telescope / nvim-tree / treesitter が動く
- [ ] zsh のプロンプト・fzf・alias、tmux の prefix C-f と window テーマ
      (OSC エスケープが WezTerm で効くか)
- [ ] espanso が launchd で起動しマッチが展開される
- [ ] VSCode が設定・キーバインドを読む
- [ ] `remote-dev` で `nixos` ホストへ接続できる(ssh config 移植の確認)
- [ ] dotfiles の deploy.sh が張った古い symlink の残骸を掃除
      (home-manager が `hm-backup` で退避するが、`~/.config/nvim/init.vim` や
      `~/.zshrc` などの symlink は事前に外しておくと衝突しない)

すべて通ったら dotfiles リポジトリを archive し、README にその旨を記す。

## メモ

- home-manager 26.05 の espanso モジュールが darwin 対応
  (launchd.agents、`Espanso.app` 参照)であることはソースで確認済み。
- Linux の `openInNvim`(foot フォールバック + xdg 連携)の Mac 版
  (WezTerm フォールバック、Finder 連携)は初回スコープ外。
  必要になったら別途検討する。
