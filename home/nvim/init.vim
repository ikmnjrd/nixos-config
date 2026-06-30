set termguicolors
set number
set clipboard=unnamedplus
set shell=/run/current-system/sw/bin/zsh
set history=200
set incsearch
set cursorline
set cursorcolumn
set cursorlineopt=both
set guicursor=n-v-c:block-Cursor,i-ci-ve:block-CursorInsert,r-cr:hor20,o:hor50
set nrformats=octal,hex,alpha
set nocompatible
filetype plugin on
runtime macros/matchit.vim

let g:mapleader = "\<Space>"
nnoremap <Leader> <Nop>
xnoremap <Leader> <Nop>
nnoremap <Leader>d "_d
xnoremap <Leader>d "_d

augroup fcitx5_integration
  autocmd!
  autocmd InsertLeave * call system('fcitx5-remote -c')
augroup END

if !exists('g:vscode')
  set autoindent
  set breakindent
  set expandtab
  set nostartofline
  set tabstop=2
  set shiftwidth=2
  set smartindent

  let g:loaded_ruby_provider = 0
  let g:loaded_perl_provider = 0

  let g:coc_global_extensions = [
    \ 'coc-tsserver',
    \ 'coc-eslint8',
    \ 'coc-prettier',
    \ 'coc-git',
    \ 'coc-fzf-preview',
    \ 'coc-lists',
    \ 'coc-snippets',
    \ 'coc-prisma',
    \ 'coc-rust-analyzer',
    \ 'coc-deno',
    \ ]

  function! s:show_documentation() abort
    if index(['vim', 'help'], &filetype) >= 0
      execute 'h ' . expand('<cword>')
    elseif coc#rpc#ready()
      call CocActionAsync('doHover')
    endif
  endfunction

  lua << EOF
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  require('nvim-tree').setup({
    diagnostics = {
      enable = true,
      show_on_dirs = true,
      icons = {
        hint = '󰌶',
        info = '󰋽',
        warning = '󰀪',
        error = '󰅚',
      },
    },
    filters = {
      dotfiles = false,
    },
    git = {
      enable = true,
      show_on_dirs = true,
    },
    modified = {
      enable = true,
    },
    renderer = {
      group_empty = true,
      highlight_diagnostics = 'icon',
      highlight_git = 'icon',
      highlight_modified = 'icon',
      indent_markers = {
        enable = true,
      },
      icons = {
        git_placement = 'before',
        modified_placement = 'after',
        show = {
          file = true,
          folder = true,
          folder_arrow = true,
          git = true,
          modified = true,
          diagnostics = true,
        },
        glyphs = {
          modified = '●',
          git = {
            unstaged = 'M',
            staged = 'S',
            unmerged = 'U',
            renamed = 'R',
            untracked = '?',
            deleted = 'D',
            ignored = '◌',
          },
        },
      },
    },
    update_focused_file = {
      enable = true,
    },
    view = {
      signcolumn = 'yes',
      width = 34,
    },
  })

  vim.keymap.set('n', '<Leader>e', '<Cmd>NvimTreeToggle<CR>', {
    desc = 'Toggle file explorer',
    silent = true,
  })
  vim.keymap.set('n', '<Leader>E', '<Cmd>NvimTreeFindFile<CR>', {
    desc = 'Reveal current file in explorer',
    silent = true,
  })

  require('toggleterm').setup({
    direction = 'float',
    open_mapping = [[<C-\>]],
    persist_mode = true,
    shade_terminals = false,
    float_opts = {
      border = 'curved',
      width = function()
        return math.floor(vim.o.columns * 0.95)
      end,
      height = function()
        return math.floor(vim.o.lines * 0.90)
      end,
    },
  })

  local lazygit = require('toggleterm.terminal').Terminal:new({
    cmd = 'lazygit',
    direction = 'float',
    dir = 'git_dir',
    hidden = true,
    float_opts = {
      border = 'curved',
      width = function()
        return math.floor(vim.o.columns * 0.95)
      end,
      height = function()
        return math.floor(vim.o.lines * 0.90)
      end,
    },
    on_open = function(terminal)
      vim.cmd.startinsert()
      vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], {
        buffer = terminal.bufnr,
        desc = 'Leave terminal mode',
        silent = true,
      })
      vim.keymap.set('t', '<C-g>', function()
        terminal:toggle()
      end, {
        buffer = terminal.bufnr,
        desc = 'Close lazygit',
        silent = true,
      })
    end,
  })

  vim.keymap.set('n', '<Leader>gg', function()
    lazygit:toggle()
  end, {
    desc = 'Open lazygit',
    silent = true,
  })

  local window_index = vim.env.TMUX_PANE
    and vim.fn.system({ 'tmux', 'display-message', '-p', '-t', vim.env.TMUX_PANE, '#{window_index}' }):gsub('%s+$', '')
    or ''

  local colorscheme = 'everforest'
  if window_index == '2' then
    colorscheme = 'gruvbox'
    require('gruvbox').setup({ transparent_mode = true })
  elseif window_index == '3' then
    colorscheme = 'catppuccin-mocha'
    require('catppuccin').setup({ transparent_background = true })
  elseif window_index == '4' then
    colorscheme = 'solarized'
    vim.g.solarized_disable_background = true
  else
    vim.g.everforest_background = 'medium'
    vim.g.everforest_transparent_background = 1
    vim.g.everforest_enable_italic = 0
  end

  vim.cmd.colorscheme(colorscheme)
  for _, group in ipairs({ 'Normal', 'NormalNC', 'NormalFloat', 'SignColumn', 'EndOfBuffer' }) do
    vim.api.nvim_set_hl(0, group, { bg = 'NONE' })
  end

  -- windowごとのテーマに合わせて、共通で上書きするUI色も切り替える。
  local theme_highlights = {
    everforest = {
      cursor_line = '#343f44',
      cursor_column = '#3d484d',
      cursor_line_nr = '#a7c080',
      cursor_fg = '#2d353b',
      cursor_bg = '#d3c6aa',
      cursor_insert = '#dbbc7f',
      whitespace = '#56635f',
      special_key = '#7a8478',
      comment = '#859289',
    },
    gruvbox = {
      cursor_line = '#3c3836',
      cursor_column = '#504945',
      cursor_line_nr = '#fabd2f',
      cursor_fg = '#282828',
      cursor_bg = '#ebdbb2',
      cursor_insert = '#fabd2f',
      whitespace = '#665c54',
      special_key = '#928374',
      comment = '#a89984',
    },
    ['catppuccin-mocha'] = {
      cursor_line = '#313244',
      cursor_column = '#45475a',
      cursor_line_nr = '#89b4fa',
      cursor_fg = '#1e1e2e',
      cursor_bg = '#cdd6f4',
      cursor_insert = '#f9e2af',
      whitespace = '#585b70',
      special_key = '#6c7086',
      comment = '#9399b2',
    },
    solarized = {
      cursor_line = '#073642',
      cursor_column = '#073642',
      cursor_line_nr = '#2aa198',
      cursor_fg = '#002b36',
      cursor_bg = '#eee8d5',
      cursor_insert = '#b58900',
      whitespace = '#586e75',
      special_key = '#657b83',
      comment = '#657b83',
    },
  }
  local highlights = theme_highlights[colorscheme] or theme_highlights.everforest
  vim.api.nvim_set_hl(0, 'CursorLine', { bg = highlights.cursor_line })
  vim.api.nvim_set_hl(0, 'CursorColumn', { bg = highlights.cursor_column })
  vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = highlights.cursor_line_nr, bold = true })
  vim.api.nvim_set_hl(0, 'Cursor', { fg = highlights.cursor_fg, bg = highlights.cursor_bg })
  vim.api.nvim_set_hl(0, 'CursorInsert', { fg = highlights.cursor_fg, bg = highlights.cursor_insert })
  vim.api.nvim_set_hl(0, 'Whitespace', { fg = highlights.whitespace })
  vim.api.nvim_set_hl(0, 'SpecialKey', { fg = highlights.special_key })
  vim.api.nvim_set_hl(0, 'Comment', { fg = highlights.comment })
  vim.api.nvim_set_hl(0, '@comment', { fg = highlights.comment })

  local function set_tmux_window_active_style(style)
    if not vim.env.TMUX_PANE then
      return
    end

    vim.fn.jobstart({
      'tmux',
      'set-option',
      '-w',
      '-t',
      vim.env.TMUX_PANE,
      'window-active-style',
      style,
    }, { detach = true })
  end

  -- tmuxのactive pane背景にnvimの透過背景を潰させない。
  set_tmux_window_active_style('bg=default')
  vim.api.nvim_create_autocmd({ 'VimLeavePre', 'VimSuspend' }, {
    callback = function()
      set_tmux_window_active_style('bg=#343f44')
    end,
  })
  vim.api.nvim_create_autocmd('VimResume', {
    callback = function()
      set_tmux_window_active_style('bg=default')
    end,
  })
EOF
endif

lua << EOF
if not vim.g.vscode then
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'prisma', 'rust', 'typescript', 'typescriptreact' },
    callback = function()
      pcall(vim.treesitter.start)
    end,
  })

  local function change_priority()
    local old_priority = vim.fn.input('Old Priority (e.g. A): ')
    local new_priority = vim.fn.input('New Priority (e.g. B): ')

    if string.match(old_priority, '^[A-Z]$') and string.match(new_priority, '^[A-Z]$') then
      local command = string.format(
        "g!/- \\[x\\]/ s/(%s)/(%s)/g",
        old_priority,
        new_priority
      )
      vim.cmd(command)
      print(string.format(
        "Replaced priority from (%s) to (%s) (excluding completed items)",
        old_priority,
        new_priority
      ))
    else
      print('Invalid priority input')
    end
  end

  vim.api.nvim_create_user_command('ChangePriority', change_priority, {})

  vim.opt.list = true
  vim.opt.listchars:append('space:⋅')
  vim.opt.listchars:append('eol:↴')
  require('ibl').setup {}
end
EOF
