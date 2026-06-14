# nixos-config

このリポジトリは、ホスト名 `nixos` の NixOS 構成を管理するための
信頼できる唯一の情報源です。NixOS 26.05 ブランチに固定した Flake を
使用しています。

## 初期セットアップ

このリポジトリは、現在の `/etc/nixos` の内容を元に作成しました。
緊急時に `/etc/nixos` から設定を取り込んでも Flake のサポートが
失われないように、Nix の設定は `hosts/nixos/repository.nix` に分離して
います。ユーザー `ikd` の開発環境は Home Manager を使い、
`home/ikd.nix` で管理します。

初回の切り替え前に設定内容を確認し、次を実行します。

```sh
./bin/nixos-config check
./bin/nixos-config build
sudo nixos-rebuild switch \
  --option experimental-features "nix-command flakes" \
  --flake "path:$PWD#nixos"
```

リポジトリは `main` をデフォルトブランチとして初期化済みです。
初回の切り替えによりHome Managerのユーザー環境が作成され、
`nix-command` と `flakes` が継続的に有効になります。

## 日常的な操作

システム設定は `hosts/nixos`、ユーザー環境は `home/ikd.nix` 以下を編集し、
検証してから反映します。

```sh
./bin/nixos-config check
./bin/nixos-config build
./bin/nixos-config test
./bin/nixos-config switch
```

`test` は起動時のデフォルト世代を変更せず、一時的に構成を有効化します。
動作を確認した後に `switch` を実行します。

緊急時に `/etc/nixos` を直接編集した場合は、表示される差分を確認してから、
管理対象の2ファイルだけを取り込みます。

```sh
./bin/nixos-config sync-from-etc
```

通常の編集場所として `/etc/nixos` を使用しないでください。
`configuration.bak.nix` は意図的に管理対象外としています。
リポジトリだけを変更した後に `/etc/nixos` との差分があるのは正常です。
`/etc/nixos` に意図した緊急修正が含まれている場合を除き、
`sync-from-etc` による取り込みは行わないでください。古い設定に戻る可能性が
あります。

## Flatpak アプリケーション

システム全体で使用する Flatpak アプリケーションとリモートは
`hosts/nixos/flatpak.nix` で宣言します。Flathub は自動的に登録され、
宣言したアプリケーションは NixOS の有効化後に
`flatpak-managed-install` systemd サービスによってインストールされます。

Flathub のアプリケーションを追加する場合は、そのアプリケーション ID を
`services.flatpak.packages` に追加します。

Brave（`com.brave.Browser`）は HTTP、HTTPS、HTML、XHTML の既定アプリです。
Flatpak アプリケーションは NixOS の有効化時、および毎週月曜日と木曜日の
午前3時に更新されます。

初回の有効化では、宣言したアプリケーションがシステム全体のインストールへ
移行します。`flatpak list --system` に表示されることを確認した後、
ランチャーの重複を避けるため、以前のユーザー単位のインストールを削除します。

```sh
flatpak uninstall --user com.brave.Browser com.onepassword.OnePassword
```

## ロールバック

過去の世代を一覧表示し、以前の構成へ戻すには次を実行します。

```sh
sudo nixos-rebuild list-generations
sudo nixos-rebuild switch --rollback
```

`hosts/nixos/hardware-configuration.nix` は、このマシンのディスクや
ハードウェア構成を記述しているため管理対象に含めていますが、通常は手動で
編集しません。

## Home Manager

`home/.gitconfig` は
`https://github.com/ikmnjrd/dotfiles/blob/main/.gitconfig` から取り込んだ
設定です。Home Managerが `/home/ikd/.gitconfig` をNix store内の
管理対象ファイルへリンクします。

`home/ikd.nix` はGit、Git LFS、GitHub CLI、Neovim、foot、Zsh、tmux、
fzf、batと開発用CLIをユーザー単位で管理します。既存の管理対象ファイルと
衝突した場合は、初回の有効化時に拡張子 `.hm-backup` で退避します。

## Remote development host

PCまたはMac側の `remote-dev` CLIから、Git worktreeを
`/home/ikd/workspace/remote-dev/<host>/<project>/<slot>/src` へ
一方向同期して実行できます。NixOS側のコピーは実行専用であり、直接編集
しません。

初回は各ホストで専用鍵を作成します。

```sh
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_nixos_remote_dev
cat ~/.ssh/id_ed25519_nixos_remote_dev.pub
```

表示された公開鍵を `hosts/nixos/remote-dev-keys.nix` に追加して
`./bin/nixos-config test` を実行します。鍵リストが空の間だけSSHの
パスワード認証が維持され、1本以上追加すると鍵認証専用へ切り替わります。
PCとMacの両方から接続できることを確認してから `switch` してください。

この構成では次も有効になります。

- `nixos.local` で到達するためのAvahi/mDNS
- Docker EngineとDocker Compose
- SSH切断後も開発unitを維持するuser linger
- AC接続中の自動サスペンド無効化
- `remote-dev-helper` によるslot、ポート、systemd user unitの管理

開発サーバーはNixOSのloopbackだけに公開し、NixOS本体のブラウザから
`remote-dev status` が表示するURLを開きます。NixOS再起動後は古いソースや
秘密情報で自動起動せず、ホストから再度 `remote-dev up` を実行します。
