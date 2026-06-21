set termguicolors
set number
set clipboard=unnamedplus
set shell=/run/current-system/sw/bin/zsh
set history=200
set incsearch
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

  local window_index = vim.env.TMUX_PANE
    and vim.fn.system({ 'tmux', 'display-message', '-p', '-t', vim.env.TMUX_PANE, '#{window_index}' }):gsub('%s+$', '')
    or ''

  local colorscheme = 'nord'
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
    vim.g.nord_contrast = true
    vim.g.nord_borders = false
    vim.g.nord_disable_background = true
    vim.g.nord_italic = false
    vim.g.nord_uniform_diff_background = true
  end

  vim.cmd.colorscheme(colorscheme)
  for _, group in ipairs({ 'Normal', 'NormalNC', 'NormalFloat', 'SignColumn', 'EndOfBuffer' }) do
    vim.api.nvim_set_hl(0, group, { bg = 'NONE' })
  end
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
