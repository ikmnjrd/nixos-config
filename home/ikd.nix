{
  username ? "ikd",
  homeDirectory ? "/home/${username}",
}:
{ lib, pkgs, ... }:

let
  fcitxIdleEnglish = pkgs.writeTextFile {
    name = "fcitx-idle-english";
    destination = "/bin/fcitx-idle-english";
    executable = true;
    text = ''
      #!${pkgs.gjs}/bin/gjs

      const { Gio, GLib, GLibUnix } = imports.gi;

      const busName = "org.gnome.Mutter.IdleMonitor";
      const objectPath = "/org/gnome/Mutter/IdleMonitor/Core";
      const interfaceName = "org.gnome.Mutter.IdleMonitor";
      const loop = GLib.MainLoop.new(null, false);
      let watchId = 0;

      const proxy = Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SESSION,
        Gio.DBusProxyFlags.NONE,
        null,
        busName,
        objectPath,
        interfaceName,
        null,
      );

      [watchId] = proxy.call_sync(
        "AddIdleWatch",
        new GLib.Variant("(t)", [15000]),
        Gio.DBusCallFlags.NONE,
        -1,
        null,
      ).deepUnpack();

      proxy.connect("g-signal", (_proxy, _senderName, signalName, parameters) => {
        if (signalName !== "WatchFired")
          return;

        const [firedWatchId] = parameters.deepUnpack();
        if (firedWatchId !== watchId)
          return;

        Gio.Subprocess.new(
          ["${pkgs.fcitx5}/bin/fcitx5-remote", "-c"],
          Gio.SubprocessFlags.NONE,
        );
      });

      function shutdown() {
        if (watchId !== 0) {
          try {
            proxy.call_sync(
              "RemoveWatch",
              new GLib.Variant("(u)", [watchId]),
              Gio.DBusCallFlags.NONE,
              -1,
              null,
            );
          } catch (error) {
            logError(error);
          }
        }
        loop.quit();
        return GLib.SOURCE_REMOVE;
      }

      GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, 2, shutdown);
      GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, 15, shutdown);
      loop.run();
    '';
  };
  pscircleWallpaper = pkgs.writeShellApplication {
    name = "pscircle-wallpaper";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.glib
      pkgs.pscircle
    ];
    text = ''
      wallpaper_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/pscircle"
      wallpaper_index=$(( ($(date +%s) / 30) % 2 ))
      wallpaper="$wallpaper_dir/wallpaper-$wallpaper_index.png"
      wallpaper_uri="file://$wallpaper"

      mkdir -p "$wallpaper_dir"

      pscircle \
        --background-color=2e3440 \
        --tree-font-color=d8dee9 \
        --dot-color-min=81a1c1 \
        --dot-color-max=bf616a \
        --dot-border-color-min=e5e9f0 \
        --dot-border-color-max=eceff4 \
        --link-color-min=4c566a \
        --link-color-max=88c0d0 \
        --toplists-font-color=d8dee9 \
        --toplists-pid-font-color=88c0d0 \
        --toplists-bar-background=3b4252 \
        --toplists-bar-color=a3be8c \
        --output="$wallpaper"

      gsettings set org.gnome.desktop.background picture-uri "$wallpaper_uri"
      gsettings set org.gnome.desktop.background picture-uri-dark "$wallpaper_uri"
    '';
  };
in
{
  home = {
    inherit username homeDirectory;
    stateVersion = "26.05";

    #現状はcodex(cli)用
    sessionPath = [
      "$HOME/.local/bin"
    ];

    sessionVariables = {
      # Deno itself is upgraded through the pinned Nixpkgs input.
      DENO_NO_UPDATE_CHECK = "1";
      QT_IM_MODULE = "fcitx";
      QT_IM_MODULES = "wayland;fcitx";
    };

    packages = with pkgs; [
      claude-code
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
      pscircle
      ripgrep
      sqlite
      nerd-fonts.sauce-code-pro
      tree
      wl-clipboard
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
            *) theme="nord" ;;
          esac

          case "$2" in
            bat)
              case "$theme" in
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

            # Bypass tmux's per-pane color state so foot keeps its configured alpha.
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
      ];
    };
    "org/gnome/mutter" = {
      overlay-key = "";
    };
    "org/gnome/shell/keybindings" = {
      toggle-overview = [ "<Super>d" ];
    };
    "org/gnome/settings-daemon/plugins/xsettings" = {
      overrides = [
        (lib.gvariant.mkDictionaryEntry "Gtk/IMModule" (lib.gvariant.mkVariant "fcitx"))
      ];
    };
    "org/gnome/desktop/background" = {
      picture-uri = "file://${homeDirectory}/.cache/pscircle/wallpaper-0.png";
      picture-uri-dark = "file://${homeDirectory}/.cache/pscircle/wallpaper-0.png";
      picture-options = "zoom";
      primary-color = "#2e3440";
      secondary-color = "#2e3440";
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/fcitx-english/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/fcitx-japanese/"
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
  };

  systemd.user.services.fcitx-idle-english = {
    Unit = {
      Description = "Switch Fcitx5 to English after 15 seconds of inactivity";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${fcitxIdleEnglish}/bin/fcitx-idle-english";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.pscircle-wallpaper = {
    Unit = {
      Description = "Render the process tree wallpaper for GNOME";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pscircleWallpaper}/bin/pscircle-wallpaper";
    };
  };

  systemd.user.timers.pscircle-wallpaper = {
    Unit = {
      Description = "Refresh the process tree wallpaper";
    };
    Timer = {
      OnBootSec = "20s";
      OnUnitActiveSec = "30s";
      Unit = "pscircle-wallpaper.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

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
        main = {
          term = "xterm-256color";
          font = "SauceCodePro Nerd Font:size=12";
          pad = "0x0";
        };

        colors-dark = {
          alpha = 0.9;
          alpha-mode = "all";
          foreground = "d8dee9";
          background = "2e3440";

          regular0 = "3b4252";
          regular1 = "bf616a";
          regular2 = "a3be8c";
          regular3 = "ebcb8b";
          regular4 = "81a1c1";
          regular5 = "b48ead";
          regular6 = "88c0d0";
          regular7 = "e5e9f0";

          bright0 = "4c566a";
          bright1 = "bf616a";
          bright2 = "a3be8c";
          bright3 = "ebcb8b";
          bright4 = "81a1c1";
          bright5 = "b48ead";
          bright6 = "8fbcbb";
          bright7 = "eceff4";

          dim0 = "373e4d";
          dim1 = "94545d";
          dim2 = "809575";
          dim3 = "b29e75";
          dim4 = "68809a";
          dim5 = "8c738c";
          dim6 = "6d96a5";
          dim7 = "aeb3bb";

          selection-foreground = "d8dee9";
          selection-background = "4c566a";
        };
      };
    };
    home-manager.enable = true;

    neovim = {
      enable = true;
      defaultEditor = true;
      withNodeJs = true;
      plugins = with pkgs.vimPlugins; [
        coc-nvim
        vim-gina
        nvim-tree-lua
        nvim-web-devicons
        toggleterm-nvim
        (nvim-treesitter.withPlugins (parsers: with parsers; [
          prisma
          rust
          tsx
          typescript
        ]))
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
      extraConfig = ''
        set -g terminal-overrides 'xterm*:smcup@:rmcup@'
        set -ag terminal-overrides ",$TERM:Tc"
        set -g bell-action any
        set -g prefix2 C-b
        # Fcitxが日本語入力の状態だと、Ctrl-fがtmux標準のprefixであるC-bとして届き、
        # 後続のASCIIキーが全角文字として届くことがある。その状態でもtmuxに無視されないよう、
        # 実用上使うprefixバインドを全角文字側にも複製する。
        # 全角の<と>は意図的に省いている。tmux標準の割り当てがセミコロン区切りの
        # サブコマンドを含む長いdisplay-menuで、ここに複製すると壊れやすい割に利用頻度が低い。
        bind-key ！ break-pane
        bind-key ＂ split-window
        bind-key ＃ list-buffers
        bind-key ＄ command-prompt -I "#S" { rename-session "%%" }
        bind-key ％ split-window -h
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
        # Keep standard shell shortcuts even though EDITOR/VISUAL point to nvim.
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
