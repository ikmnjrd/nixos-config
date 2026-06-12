# NixOS 構成作業記録

最終更新: 2026-06-12（Asia/Tokyo）

## 目的

このマシンの NixOS 構成を Flake と、繰り返し実行可能な
check/build/test/switch の手順を使って、このリポジトリから管理します。
このリポジトリを信頼できる唯一の情報源とし、`/etc/nixos` は緊急時の
取り込み元としてのみ使用します。

## 完了した作業

- 現在の `/etc/nixos/configuration.nix` と
  `/etc/nixos/hardware-configuration.nix` を `hosts/nixos/` にコピーした。
- NixOS 26.05 の nixpkgs ブランチを使用する
  `nixosConfigurations.nixos` を定義した `flake.nix` を追加した。
- `flake.lock` を生成し、2026-06-08 時点の nixpkgs リビジョン
  `bd0ff2d3eac24699c3664d5966b9ef36f388e2ca` に固定した。
- `hosts/nixos/repository.nix` を追加し、次を設定した。
  - Git のインストール
  - `nix-command` と `flakes` の有効化
- `bin/nixos-config` に次のコマンドを追加した。
  - `sync-from-etc`
  - `check`
  - `build`
  - `test`
  - `switch`
- `.gitignore` と `README.md` を追加した。
- `.git` を `main` ブランチで初期化した。
- グローバルな Git ユーザー情報の設定を後回しにしたため、
  この時点ではコミットを作成しなかった。
- 2026-06-12 に Flake 構成を正常に有効化した。
- 次を確認した。
  - `/run/current-system/sw/bin/git` から Git 2.54.0 を使用できる。
  - `/etc/nix/nix.conf` で `nix-command flakes` が有効になっている。
  - 初期状態で `sync-from-etc` に差分がない。
  - `result` と `result-*` が無視される。
  - `./bin/nixos-config check` が成功する。
  - `./bin/nixos-config build` が成功する。
- 名前が変更された GNOME と GDM のオプションを、現在の NixOS の名前に
  更新した。警告を解消した最終設定も正常に反映された。
- 最終的な `./bin/nixos-config check` が警告なしで成功することを確認した。
- この時点のシステムパスは次のとおり。
  `/nix/store/kch4yg0w55n3wlmklk01rxnkgs5xcz1s-nixos-system-nixos-26.05.20260608.bd0ff2d`

## 初回有効化に関する記録

初回の有効化は完了しています。次のコマンドは、復旧時または新規環境の
セットアップ用として残しています。

初回の有効化では、コマンドラインで Flake を明示的に有効化する必要が
あります。

```sh
cd /home/ikd/workspace/nixos-config
sudo nixos-rebuild switch \
  --option experimental-features "nix-command flakes" \
  --flake "path:$PWD#nixos"
```

この操作により Git がインストールされ、実験的機能の設定が永続化されます。

以前は `--extra-experimental-features` を使用しましたが、この環境の
`nixos-rebuild` では、その Nix グローバル引数を受け付けませんでした。
上記の対応している `--option` 形式を使用します。

## 作業再開時のチェックリスト

次回のセッションでは、次を実行します。

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

その後、最初のコミットを作成する前にグローバルな Git ユーザー情報を
設定します。

```sh
git config --global user.name "<name>"
git config --global user.email "<email>"
git commit -m "Initialize NixOS configuration"
```

接続先が決まるまでは GitHub のリモートを追加しません。

## 残っている確認事項

- 必要な NixOS とホームディレクトリの設定を引き続き追加する。

## 注意事項

- `configuration.bak.nix` は意図的に管理対象外としている。
- 緊急時に `sync-from-etc` を実行しても Git や Flake のサポートが
  削除されないように、`hosts/nixos/repository.nix` を分離している。
- Flake の切り替えでは `/etc/nixos` は書き換えられない。
  リポジトリを変更した後に差分があるのは正常である。
  `/etc/nixos` に意図した新しい緊急修正が含まれている場合に限り、
  `sync-from-etc` による取り込みを行う。
- `hosts/nixos/hardware-configuration.nix` はこのマシンの構成を記述する
  ファイルであり、通常は手動で編集しない。

## Git 設定変更の記録

2026-06-12 に、`https://github.com/ikmnjrd/dotfiles` にある最新の
`.gitconfig` を `home/.gitconfig` として追加しました。

`hosts/nixos/repository.nix` では次を設定しています。

- `/home/ikd/.gitconfig` から管理対象ファイルへのシンボリックリンクを作成する。
- 取り込んだ設定が参照する `git-lfs`、`gh`、`neovim` をインストールする。

ユーザーに切り替えを依頼する前に、次を実行します。

```sh
./bin/nixos-config check
./bin/nixos-config build
git add .
git diff --cached --check
```

ユーザーが `./bin/nixos-config switch` を実行した後、次を確認します。

```sh
readlink -f /home/ikd/.gitconfig
git config --global --get user.name
git config --global --get user.email
git config --global --get core.editor
git lfs version
gh --version
nvim --version
```

## GitHub との接続

Git の設定を反映し、次の初期コミットを作成しました。

```text
24f073f init
```

その時点の状態は次のとおりです。

- Git のリモートは未設定。
- `/home/ikd/.ssh` に鍵や SSH 設定は存在しない。
- `gh auth status` では認証済みの GitHub ホストがない。
- Git ユーザー情報は
  `ike <40803799+ikmnjrd@users.noreply.github.com>`。

GitHub へ対話的に認証し、GitHub CLI に SSH 鍵の作成と登録を行わせます。

```sh
gh auth login --hostname github.com --git-protocol ssh --web
```

認証情報と SSH 秘密鍵は、このリポジトリの外部で管理する必要があります。
Nix 構成や Git の管理対象には追加しません。

認証後、次を確認します。

```sh
gh auth status
ssh -T git@github.com
```

その後、`gh repo create` の実行または既存リポジトリを `origin` として
追加する前に、リポジトリ名と公開範囲を決定します。

GitHub との接続は 2026-06-12 に完了し、次を確認しました。

- GitHub CLI のアカウント: `ikmnjrd`
- Git プロトコル: SSH
- `ssh -T git@github.com` による認証に成功
- リモート: `git@github.com:ikmnjrd/nixos-config.git`
- リポジトリ: `https://github.com/ikmnjrd/nixos-config`
- 公開範囲: public
- ローカルの `main` と `origin/main` はコミット `24f073f` で同期済み
