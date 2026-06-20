{ pkgs, ... }:

{
  home = {
    username = "ikd";
    homeDirectory = "/home/ikd";
    stateVersion = "26.05";

    #現状はcodex(cli)用
    sessionPath = [
      "$HOME/.local/bin"
    ];

    packages = with pkgs; [
      _1password-cli
      claude-code
      fd
      gh
      ghq
      git
      git-lfs
      glow
      jq
      peco
      ripgrep
      sqlite
      source-code-pro
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
    "org/gnome/mutter" = {
      overlay-key = "F1";
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
          font = "Source Code Pro:size=10.5";
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
        vim-fern
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
