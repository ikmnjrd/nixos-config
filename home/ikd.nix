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
      fd
      gh
      ghq
      git
      git-lfs
      jq
      peco
      ripgrep
      source-code-pro
      tree
    ];

    file.".gitconfig".source = ./.gitconfig;
  };

  programs = {
    bat.enable = true;
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
        ls = "ls --color=auto";
        ll = "ls -l --color=auto";
        l = "ls -al --color=auto";
      };

      initContent = ''
        export BAT_THEME="Nord"
        export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview "bat --color=always --style=header,grid --line-range :100 {}"'
        export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

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
