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
      source-code-pro
      tree
      wl-clipboard
    ];

    file = {
      ".gitconfig".source = ./.gitconfig;
      ".config/git/ignore".source = ./git-ignore;
      ".config/Code/User/settings.json".source = ./vscode/settings.json;
      ".config/Code/User/keybindings.json".source = ./vscode/keybindings.json;
    };
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
        nord-nvim
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
        export BAT_THEME="Nord"
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
