{
  username,
  homeDirectory ? "/home/${username}",
  inputs,
}:
{ lib, pkgs, config, ... }:

let
  aiToolsUpdatePath = lib.makeBinPath (with pkgs; [
    bash
    coreutils
    curl
    findutils
    gawk
    gnugrep
    gnused
    gnutar
    gzip
    git
    nix
    openssl
    util-linux
  ]);

  # 公式インストーラ(standalone方式)はcurrentシンボリックリンクを最新版に向ける。
  codexCli = pkgs.writeShellScriptBin "codex" ''
    exec "$HOME/.codex/packages/standalone/current/bin/codex" "$@"
  '';

  gyazo = pkgs.writeShellApplication {
    name = "gyazo";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnome-screenshot
      jq
      libnotify
      libsecret
      wl-clipboard
      xdg-utils
    ];
    text = builtins.readFile ./scripts/gyazo;
  };

  gyazoTokenSet = pkgs.writeShellApplication {
    name = "gyazo-token-set";
    runtimeInputs = with pkgs; [
      libnotify
      libsecret
    ];
    text = builtins.readFile ./scripts/gyazo-token-set;
  };

  # 公式Linux版を日次で追従するupstreamのFHSパッケージを使う。
  claudeDesktopPackage =
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default;

  espansoWlPaste = pkgs.writeShellScriptBin "wl-paste" ''
    out_file="$(mktemp)"
    err_file="$(mktemp)"
    if ${pkgs.wl-clipboard}/bin/wl-paste "$@" >"$out_file" 2>"$err_file"; then
      if cat "$out_file" "$err_file" | grep -q "Nothing is copied"; then
        rm -f "$out_file" "$err_file"
        exit 0
      fi

      cat "$out_file"
      rm -f "$out_file" "$err_file"
      exit 0
    fi

    status="$?"
    if [ "$status" -eq 1 ] && cat "$out_file" "$err_file" | grep -q "Nothing is copied"; then
      rm -f "$out_file" "$err_file"
      exit 0
    fi

    cat "$out_file"
    cat "$err_file" >&2
    rm -f "$out_file" "$err_file"
    exit "$status"
  '';

  espansoWayland = pkgs.writeShellScriptBin "espanso" ''
    export PATH="${espansoWlPaste}/bin:${pkgs.wl-clipboard}/bin:${pkgs.setxkbmap}/bin:${pkgs.libnotify}/bin:$PATH"
    exec -a "$0" "${pkgs.espanso-wayland}/bin/.espanso-wrapped" "$@"
  '';

  textEditorMimeTypes = [
    "text/plain"
    "text/markdown"
    "text/x-markdown"
    "text/x-readme"
    "text/x-log"
    "text/x-c"
    "text/x-c++"
    "text/x-chdr"
    "text/x-csrc"
    "text/x-c++hdr"
    "text/x-c++src"
    "text/x-go"
    "text/x-java"
    "text/x-lua"
    "text/x-makefile"
    "text/x-nix"
    "text/x-perl"
    "text/x-python"
    "text/x-ruby"
    "text/x-rustsrc"
    "text/x-sql"
    "text/x-vim"
    "application/javascript"
    "application/json"
    "application/sql"
    "application/toml"
    "application/x-desktop"
    "application/x-shellscript"
    "application/x-toml"
    "application/x-yaml"
    "application/xml"
    "application/yaml"
  ];

  openInNvim = pkgs.writeShellScriptBin "open-in-nvim" ''
    set -euo pipefail

    first_path="''${1:-$HOME}"
    if [ -d "$first_path" ]; then
      start_dir="$first_path"
    else
      start_dir="$(${pkgs.coreutils}/bin/dirname -- "$first_path")"
    fi

    window_name="nvim"
    if [ "$#" -gt 0 ]; then
      window_name="nvim: $(${pkgs.coreutils}/bin/basename -- "$first_path")"
    fi

    select_tmux_session() {
      ${pkgs.tmux}/bin/tmux list-clients -F '#{session_name}' 2>/dev/null |
        ${pkgs.coreutils}/bin/head -n 1 || true
    }

    open_in_tmux() {
      session="$(select_tmux_session)"
      [ -n "$session" ] || return 1

      if [ "$#" -gt 0 ]; then
        command_parts=("${config.programs.neovim.finalPackage}/bin/nvim" -- "$@")
      else
        command_parts=("${config.programs.neovim.finalPackage}/bin/nvim")
      fi

      shell_command=""
      for part in "''${command_parts[@]}"; do
        printf -v quoted_part '%q' "$part"
        shell_command="$shell_command $quoted_part"
      done
      shell_command="''${shell_command# }"

      ${pkgs.tmux}/bin/tmux new-window \
        -t "$session:" \
        -c "$start_dir" \
        -n "$window_name" \
        "$shell_command" || return 1
    }

    # 画面上にtmuxクライアントがある場合は、そのセッションへnvim用windowを増やす。
    if open_in_tmux "$@"; then
      exit 0
    fi

    exec ${pkgs.foot}/bin/foot --working-directory="$start_dir" ${config.programs.neovim.finalPackage}/bin/nvim -- "$@"
  '';
in
{
  home = {
    inherit username homeDirectory;
    stateVersion = "26.05";

    # 現状はcodex(cli)用
    sessionPath = [
      "$HOME/.local/bin"
    ];

    sessionVariables = {
      # proxy経由では組織設定の初期化がタイムアウトするため、デスクトップから直接起動する。
      CODEX_REMOTE_CONTROL_APP_SERVER_MODE = lib.mkForce "direct";
      # Deno自体は固定したNixpkgs inputで更新する。
      DENO_NO_UPDATE_CHECK = "1";
      QT_IM_MODULE = "fcitx";
      QT_IM_MODULES = "wayland;fcitx";
    };

    packages = (with pkgs; [
      deno
      fd
      gh
      ghq
      git
      git-lfs
      glow
      jq
      lazygit
      peco
      ripgrep
      sqlite
      nerd-fonts.sauce-code-pro
      tree
      wl-clipboard
    ]) ++ [
      # ターミナルでもcodexをstandalone本体へ橋渡しする(cliPackageと同一)。
      claudeDesktopPackage
      codexCli
      gyazo
      gyazoTokenSet
      openInNvim
    ];

    file = {
      ".gitconfig".source = ./.gitconfig;
      ".config/git/ignore".source = ./git-ignore;
      ".config/Code/User/settings.json".source = ./vscode/settings.json;
      ".config/Code/User/keybindings.json".source = ./vscode/keybindings.json;
      ".config/tmux/window-theme" = {
        executable = true;
        text = ''
          #!/bin/sh

          window_index="$1"
          if [ -z "$window_index" ] && [ -n "$TMUX_PANE" ]; then
            window_index="$(tmux display-message -p -t "$TMUX_PANE" '#{window_index}')"
          fi

          case "$window_index" in
            2) theme="gruvbox" ;;
            3) theme="catppuccin" ;;
            4) theme="solarized" ;;
            *) theme="everforest" ;;
          esac

          case "$2" in
            bat)
              case "$theme" in
                everforest) echo "ansi" ;;
                gruvbox) echo "gruvbox-dark" ;;
                catppuccin) echo "Catppuccin Mocha" ;;
                solarized) echo "Solarized (dark)" ;;
                nord) echo "Nord" ;;
              esac
              ;;
            *) echo "$theme" ;;
          esac
        '';
      };
      ".local/bin/bat" = {
        executable = true;
        text = ''
          #!/bin/sh

          theme="$("$HOME/.config/tmux/window-theme" "" bat)"
          exec ${pkgs.bat}/bin/bat --theme "$theme" "$@"
        '';
      };
      ".local/bin/ai-tools-update" = {
        executable = true;
        text = ''
          #!/bin/sh
          set -eu

          local_bin="$HOME/.local/bin"
          export PATH="$local_bin:${aiToolsUpdatePath}:''${PATH:-}"

          need_cmd() {
            if ! command -v "$1" >/dev/null 2>&1; then
              printf '%s\n' "missing required command: $1" >&2
              exit 1
            fi
          }

          need_cmd curl
          need_cmd nix
          need_cmd sh
          need_cmd bash

          nixos_config_dir="$HOME/workspace/nixos-config"

          mkdir -p "$local_bin"
          tmp_dir="$(mktemp -d)"
          trap 'rm -rf "$tmp_dir"' EXIT

          # Claude Codeは公式のネイティブインストーラでlatestチャンネルを使う。
          printf '%s\n' "Updating Claude Code..."
          curl -fsSL https://claude.ai/install.sh -o "$tmp_dir/claude-install.sh"
          bash "$tmp_dir/claude-install.sh" latest

          # Codex CLIは公式のCodexインストーラで更新する。
          printf '%s\n' "Updating Codex..."
          curl -fsSL https://chatgpt.com/codex/install.sh -o "$tmp_dir/codex-install.sh"
          CODEX_NON_INTERACTIVE=1 sh "$tmp_dir/codex-install.sh"

          if [ -f "$nixos_config_dir/flake.nix" ]; then
            # Claude Desktopは公式APT版を追従するflake inputから導入する。
            printf '%s\n' "Updating Claude Desktop..."
            nix flake update claude-desktop --flake "$nixos_config_dir"

            # Codex Desktop Linuxはflake inputとしてHome Managerから導入する。
            printf '%s\n' "Updating Codex Desktop Linux..."
            nix flake update codex-desktop-linux --flake "$nixos_config_dir"
          else
            printf '%s\n' "Skipping Codex Desktop Linux update: $nixos_config_dir/flake.nix not found" >&2
          fi

          printf '\n%s\n' "Installed versions:"
          if command -v claude >/dev/null 2>&1; then
            claude --version || true
          fi
          if command -v codex >/dev/null 2>&1; then
            codex --version || true
          fi
        '';
      };
      ".config/tmux/apply-window-theme" = {
        executable = true;
        text = ''
          #!/bin/sh

          target="$1"
          theme="$("$HOME/.config/tmux/window-theme" "$2")"

          case "$theme" in
            gruvbox)
              background="#282828"
              foreground="#ebdbb2"
              palette="282828 cc241d 98971a d79921 458588 b16286 689d6a a89984 928374 fb4934 b8bb26 fabd2f 83a598 d3869b 8ec07c ebdbb2"
              ;;
            catppuccin)
              background="#1e1e2e"
              foreground="#cdd6f4"
              palette="45475a f38ba8 a6e3a1 f9e2af 89b4fa f5c2e7 94e2d5 bac2de 585b70 f38ba8 a6e3a1 f9e2af 89b4fa f5c2e7 94e2d5 a6adc8"
              ;;
            solarized)
              background="#002b36"
              foreground="#839496"
              palette="073642 dc322f 859900 b58900 268bd2 d33682 2aa198 eee8d5 002b36 cb4b16 586e75 657b83 839496 6c71c4 93a1a1 fdf6e3"
              ;;
            everforest)
              background="#2d353b"
              foreground="#d3c6aa"
              palette="475258 e67e80 a7c080 dbbc7f 7fbbb3 d699b6 83c092 d3c6aa 7a8478 e67e80 a7c080 dbbc7f 7fbbb3 d699b6 83c092 d3c6aa"
              ;;
            nord)
              background="#2e3440"
              foreground="#d8dee9"
              palette="3b4252 bf616a a3be8c ebcb8b 81a1c1 b48ead 88c0d0 e5e9f0 4c566a bf616a a3be8c ebcb8b 81a1c1 b48ead 8fbcbb eceff4"
              ;;
          esac

          set -- $palette
          tmux list-clients -F '#{client_tty} #{window_id}' |
            while read -r client_tty client_window_id; do
            [ "$client_window_id" = "$target" ] || continue
            [ -w "$client_tty" ] || continue

            # tmuxのpaneごとの色状態を避け、footの透過設定を維持する。
            {
              printf '\033]10;%s\007\033]11;%s\007' "$foreground" "$background"
              index=0
              for color in "$@"; do
                printf '\033]4;%s;#%s\007' "$index" "$color"
                index=$((index + 1))
              done
            } > "$client_tty"
          done
        '';
      };
    };
  };

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "kimpanel@kde.org"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
      ];
    };
    "org/gnome/mutter" = {
      overlay-key = lib.mkForce "";
      # Super+Shift+数字で1〜9へ確実に移動できるよう固定ワークスペースにする。
      dynamic-workspaces = false;
    };
    "org/gnome/desktop/wm/preferences" = {
      num-workspaces = 6;
    };
    "org/gnome/shell/keybindings" = {
      toggle-overview = [
        "<Super>d"
        "<Control>Up"
        "<Alt>space"
      ];
    };
    "org/gnome/desktop/wm/keybindings" = {
      # Alt+Spaceはoverview表示に使うため、既定のウィンドウメニューを無効化する。
      activate-window-menu = [ ];
      switch-to-workspace-left = [ "<Control>Left" ];
      switch-to-workspace-right = [ "<Control>Right" ];
      # Super+Shift+数字でアクティブウィンドウを対応するワークスペースへ移動する。
      move-to-workspace-1 = [ "<Super><Shift>1" ];
      move-to-workspace-2 = [ "<Super><Shift>2" ];
      move-to-workspace-3 = [ "<Super><Shift>3" ];
      move-to-workspace-4 = [ "<Super><Shift>4" ];
      move-to-workspace-5 = [ "<Super><Shift>5" ];
      move-to-workspace-6 = [ "<Super><Shift>6" ];
    };
    "org/gnome/settings-daemon/plugins/xsettings" = {
      overrides = [
        (lib.gvariant.mkDictionaryEntry "Gtk/IMModule" (lib.gvariant.mkVariant "fcitx"))
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/fcitx-english/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/fcitx-japanese/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gyazo/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/suspend/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/fcitx-english" = {
      binding = "XF86Launch5";
      command = "${pkgs.fcitx5}/bin/fcitx5-remote -c";
      name = "Fcitx English input";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/fcitx-japanese" = {
      binding = "XF86Launch6";
      command = "${pkgs.fcitx5}/bin/fcitx5-remote -o";
      name = "Fcitx Japanese input";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gyazo" = {
      binding = "<Super><Shift>g";
      command = "${gyazo}/bin/gyazo";
      name = "Gyazo screenshot";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/suspend" = {
      binding = "<Super><Control>q";
      command = "systemctl suspend";
      name = "Suspend";
    };
  };

  services.espanso = {
    enable = true;
    x11Support = false;
    waylandSupport = true;
    package-wayland = espansoWayland;
    configs = { };
    matches = { };
  };

  systemd.user = {
    services.espanso.Service = {
      # Waylandセッション情報を取れない場合でも再起動ループに入らないようにする。
      Restart = lib.mkForce "no";
    };

    services.ai-tools-update = {
      Unit = {
        Description = "Update AI development tools";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "%h/.local/bin/ai-tools-update";
      };
    };

    timers.ai-tools-update = {
      Unit.Description = "Update AI development tools daily";
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
        Unit = "ai-tools-update.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  xdg.desktopEntries.nvim-foot = {
    name = "Neovim in foot";
    genericName = "Text Editor";
    comment = "footまたは既存のtmuxセッション越しにNeovimでファイルを開く";
    exec = "${openInNvim}/bin/open-in-nvim %F";
    icon = "nvim";
    terminal = false;
    type = "Application";
    categories = [ "Utility" "TextEditor" ];
    mimeType = textEditorMimeTypes;
  };

  xdg.mimeApps = {
    enable = true;
    associations.added = lib.genAttrs textEditorMimeTypes (_: [ "nvim-foot.desktop" ]);
    defaultApplications = lib.genAttrs textEditorMimeTypes (_: [ "nvim-foot.desktop" ]);
  };

  xdg.configFile = {
    # Nautilus(GNOME Files)のサイドバーのブックマーク。
    # このファイルで全ブックマークを上書き管理するため、既存分も明記する。
    "gtk-3.0/bookmarks".text = ''
      file://${homeDirectory}/workspace workspace
      file://${homeDirectory}/Documents Documents
      file://${homeDirectory}/Music Music
      file://${homeDirectory}/Pictures Pictures
      file://${homeDirectory}/Videos Videos
      file://${homeDirectory}/Downloads Downloads
      file://${homeDirectory}/Videos/Screencasts Screencasts
    '';
    "espanso/config/default.yml".source = ./espanso/config/default.yml;
    "espanso/match/all-emoji.yml".source = ./espanso/match/all-emoji.yml;
    "espanso/match/apple-symbol.yml".source = ./espanso/match/apple-symbol.yml;
    "espanso/match/arrow.yml".source = ./espanso/match/arrow.yml;
    "espanso/match/base.yml".source = ./espanso/match/base.yml;
    "espanso/match/coding.yml".source = ./espanso/match/coding.yml;
    "espanso/match/curl.yml".source = ./espanso/match/curl.yml;
    "espanso/match/hax.yml".source = ./espanso/match/hax.yml;
    "espanso/match/markdown.yml".source = ./espanso/match/markdown.yml;
  };

  # nvimの色はwindowごとのcolorschemeで切り替えるため、Stylixの注入から外す。
  stylix.targets.neovim.enable = false;

  programs = {
    bat.enable = true;
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
    fzf.enable = true;
    foot = {
      enable = true;
      settings = {
        "colors-dark" = {
          # tmuxのwindow-active-styleなど、通常背景以外のセル背景にもfootの透過を効かせる。
          "alpha-mode" = "all";
        };
        main = {
          term = "xterm-256color";
          font = "SauceCodePro Nerd Font:size=12";
          pad = "0x0";
        };
      };
    };
    home-manager.enable = true;
    codexDesktopLinux = {
      enable = true;
      computerUseUi.enable = true;
      remoteMobileControl.enable = true;
      remoteControl.enable = true;

      cliPackage = codexCli;
      remoteControl.package = codexCli;
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      withNodeJs = true;
      plugins = with pkgs.vimPlugins; [
        coc-nvim
        vim-gina
        mini-nvim
        nvim-tree-lua
        nvim-web-devicons
        plenary-nvim
        telescope-nvim
        toggleterm-nvim
        (nvim-treesitter.withPlugins (parsers: with parsers; [
          prisma
          rust
          tsx
          typescript
        ]))
        everforest
        catppuccin-nvim
        gruvbox-nvim
        nord-nvim
        solarized-nvim
        indent-blankline-nvim
        glow-nvim
      ];
      extraConfig = builtins.readFile ./nvim/init.vim;
    };

    tmux = {
      enable = true;
      prefix = "C-f";
      mouse = true;
      baseIndex = 1;
      escapeTime = 0;
      terminal = "screen-256color";
      extraConfig = lib.mkForce ''
        set -g terminal-overrides 'xterm*:smcup@:rmcup@'
        set -ag terminal-overrides ",$TERM:Tc"
        set -g bell-action any
        # nvim側で一時的にdefaultへ逃がし、それ以外ではactive paneを濃く装飾する。
        set -g window-active-style 'bg=#343f44'
        # active windowの装飾はステータスライン側だけに限定する。
        set -g window-status-current-style 'bg=#343f44,fg=#d3c6aa,bold'
        # prefixとして特別扱いされるキーではコマンドを実行できないため、Home Managerが設定した
        # prefixを無効化し、root tableのバインドでIMEを英数へ戻してからprefix tableへ移る。
        # Fcitxが日本語入力の状態だと、Ctrl-fがtmux標準のprefixであるC-bとして届くことがあるため、
        # C-bにも同じ処理を入れている。
        set -g prefix None
        bind-key -n C-f run-shell -b '${pkgs.fcitx5}/bin/fcitx5-remote -c' \; switch-client -T prefix
        bind-key -n C-b run-shell -b '${pkgs.fcitx5}/bin/fcitx5-remote -c' \; switch-client -T prefix
        bind-key C-f send-keys C-f
        bind-key C-b send-keys C-b
        # IMEを戻す前に後続のASCIIキーが全角文字として届く場合もあるため、
        # 実用上使うprefixバインドを全角文字側にも複製する。
        # 全角の<と>は意図的に省いている。tmux標準の割り当てがセミコロン区切りの
        # サブコマンドを含む長いdisplay-menuで、ここに複製すると壊れやすい割に利用頻度が低い。
        # 分割元paneのカレントディレクトリを新しいpaneにも引き継ぐ。
        bind-key '"' split-window -c "#{pane_current_path}"
        bind-key % split-window -h -c "#{pane_current_path}"
        bind-key ！ break-pane
        bind-key ＂ split-window -c "#{pane_current_path}"
        bind-key ＃ list-buffers
        bind-key ＄ command-prompt -I "#S" { rename-session "%%" }
        bind-key ％ split-window -h -c "#{pane_current_path}"
        bind-key ＆ confirm-before -p "kill-window #W? (y/n)" kill-window
        bind-key ＇ command-prompt -T window-target -p index { select-window -t ":%%" }
        bind-key （ switch-client -p
        bind-key ） switch-client -n
        bind-key ， command-prompt -I "#W" { rename-window "%%" }
        bind-key － select-layout main-vertical
        bind-key ． command-prompt -T target { move-window -t "%%" }
        bind-key ／ command-prompt -k -p key { list-keys -1N "%%" }
        bind-key ０ select-window -t :=0
        bind-key １ select-window -t :=1
        bind-key ２ select-window -t :=2
        bind-key ３ select-window -t :=3
        bind-key ４ select-window -t :=4
        bind-key ５ select-window -t :=5
        bind-key ６ select-window -t :=6
        bind-key ７ select-window -t :=7
        bind-key ８ select-window -t :=8
        bind-key ９ select-window -t :=9
        bind-key ： command-prompt
        bind-key ； last-pane
        bind-key ＝ choose-buffer -Z
        bind-key ？ list-keys -N
        bind-key ［ copy-mode
        bind-key ］ paste-buffer -p
        bind-key ｛ swap-pane -U
        bind-key ｜ select-layout even-vertical
        bind-key ｝ swap-pane -D
        bind-key ～ show-messages
        bind-key Ｃ customize-mode -Z
        bind-key Ｄ choose-client -Z
        bind-key Ｅ select-layout -E
        bind-key Ｌ switch-client -l
        bind-key Ｍ select-pane -M
        bind-key ｃ new-window
        bind-key ｄ detach-client
        bind-key ｆ command-prompt { find-window -Z "%%" }
        bind-key ｉ display-message
        bind-key ｌ last-window
        bind-key ｍ select-pane -m
        bind-key ｎ next-window
        bind-key ｏ select-pane -t :.+
        bind-key ｐ previous-window
        bind-key ｑ display-panes
        bind-key ｒ refresh-client
        bind-key ｓ choose-tree -Zs
        bind-key ｔ clock-mode
        bind-key ｗ choose-tree -Zw
        bind-key ｘ confirm-before -p "kill-pane #P? (y/n)" kill-pane
        bind-key ｚ resize-pane -Z
        bind-key | select-layout even-vertical
        bind-key - select-layout main-vertical
        set-hook -g after-new-window \
          'run-shell "~/.config/tmux/apply-window-theme #{window_id} #{window_index}"'
        set-hook -g after-select-window \
          'run-shell "~/.config/tmux/apply-window-theme #{window_id} #{window_index}"'
      '';
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      envExtra = ''
        mkgitrepo() {
          emulate -L zsh
          setopt err_return no_unset

          local visibility="--public"
          local repo_name=""
          local -a extra_args

          while (( $# > 0 )); do
            case "$1" in
              --public|--private|--internal)
                visibility="$1"
                ;;
              -h|--help)
                cat <<'EOF'
Usage: mkgitrepo [--public|--private|--internal] <repo> [gh repo create flags...]

Create a Git repository under ~/workspace and create its GitHub remote.
If visibility is omitted, --public is used.
EOF
                return 0
                ;;
              --)
                shift
                extra_args+=("$@")
                break
                ;;
              *)
                if [[ -z "$repo_name" ]]; then
                  repo_name="$1"
                else
                  extra_args+=("$1")
                fi
                ;;
            esac
            shift
          done

          if [[ -z "$repo_name" ]]; then
            cat >&2 <<'EOF'
Usage: mkgitrepo [--public|--private|--internal] <repo> [gh repo create flags...]
EOF
            return 1
          fi

          local local_name="''${repo_name:t}"
          local workspace="$HOME/workspace"
          local target="$workspace/$local_name"

          if [[ -z "$local_name" || "$local_name" == "." || "$local_name" == ".." ]]; then
            print -u2 "Invalid repository name: $repo_name"
            return 1
          fi

          mkdir -p "$workspace"
          mkdir "$target"
          cd "$target"

          # どこから起動しても、作業用のローカルrepoは~/workspace配下に作る。
          git init
          gh repo create "$repo_name" "$visibility" --source=. --remote=origin "''${extra_args[@]}"
        }
      '';

      shellAliases = {
        g = "git";
        vi = "nvim";
        vim = "nvim";
        view = "nvim -R";
        cat = "bat --paging=never";
        day = "date +%Y-%m-%d";
        his = "fc -l -t \"%Y-%m-%d %H:%M:%S \"";
        ls = "ls --color=auto";
        ll = "ls -l --color=auto";
        l = "ls -al --color=auto";
        pbcopy = "wl-copy";
        pbpaste = "wl-paste";
      };

      history = {
        path = "$HOME/.zsh_history";
        size = 10000;
        save = 10000;
        append = true;
        share = true;
        extended = true;
      };

      initContent = ''
        # EDITOR/VISUALがnvimでも標準のシェルショートカットを維持する。
        bindkey -e

        export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview "bat --color=always --style=header,grid --line-range :100 {}"'
        export FZF_CTRL_R_OPTS="
          --preview 'echo {}' --preview-window up:3:hidden:wrap
          --bind 'ctrl-/:toggle-preview'
          --bind 'ctrl-y:execute-silent(echo -n {2..} | wl-copy)+abort'
          --color header:italic
          --header 'Press CTRL-Y to copy command into clipboard'"
        export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

        source ${pkgs.git}/share/git/contrib/completion/git-prompt.sh
        GIT_PS1_SHOWDIRTYSTATE=true
        GIT_PS1_SHOWUNTRACKEDFILES=true
        GIT_PS1_SHOWSTASHSTATE=true
        GIT_PS1_SHOWUPSTREAM=auto
        setopt PROMPT_SUBST
        PS1='[%n@%m %c$(__git_ps1 " (%s)")]\$ '

        fbr() {
          local branch
          branch=$(git branch --format='%(refname:short)' | fzf) || return
          [[ -n "$branch" ]] && git switch "$branch"
        }

        gcd() {
          local repo
          repo=$(ghq list | peco) || return
          [[ -n "$repo" ]] && cd "$(ghq root)/$repo"
        }

        select_worktree() {
          local worktrees selected
          worktrees=$(git worktree list --porcelain | awk '/worktree / {print $2}')
          if [[ -z "$worktrees" ]]; then
            echo "No worktrees found."
            return 1
          fi

          selected=$(echo "$worktrees" | fzf)
          if [[ -n "$selected" ]]; then
            cd "$selected"
          fi
        }
      '';
    };
  };
}
