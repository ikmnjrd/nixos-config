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
            unmerged = 'X',
            renamed = 'R',
            untracked = 'U',
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

  local telescope = require('telescope')
  local telescope_builtin = require('telescope.builtin')
  local telescope_make_entry = require('telescope.make_entry')
  local telescope_themes = require('telescope.themes')

  telescope.setup({
    defaults = {
      layout_config = {
        horizontal = {
          preview_cutoff = 80,
        },
      },
    },
    pickers = {
      find_files = {
        hidden = true,
        no_ignore = false,
      },
    },
  })

  local function floating_picker_options()
    return telescope_themes.get_dropdown({
      border = true,
      previewer = true,
      width = 0.95,
      height = 0.85,
    })
  end

  local function git_status_label(index_status, worktree_status)
    local conflict_statuses = {
      DD = true,
      AU = true,
      UD = true,
      UA = true,
      DU = true,
      AA = true,
      UU = true,
    }
    if conflict_statuses[index_status .. worktree_status] then
      return 'X'
    end
    if index_status == '?' or worktree_status == '?' then
      return 'U'
    end
    if index_status == 'R' or worktree_status == 'R' then
      return 'R'
    end
    if index_status == 'D' or worktree_status == 'D' then
      return 'D'
    end

    local labels = {}
    if index_status ~= ' ' then
      table.insert(labels, 'S')
    end
    if worktree_status ~= ' ' then
      table.insert(labels, 'M')
    end
    return table.concat(labels, '')
  end

  local git_status_highlight_groups = {
    M = 'TelescopeGitModified',
    S = 'TelescopeGitStaged',
    D = 'TelescopeGitDeleted',
    R = 'TelescopeGitRenamed',
    U = 'TelescopeGitUntracked',
    X = 'TelescopeGitConflict',
  }

  local function git_status_by_path()
    if vim.fn.executable('git') ~= 1 then
      return {}
    end

    local cwd = vim.uv.cwd()
    local root_result = vim.system({ 'git', '-C', cwd, 'rev-parse', '--show-toplevel' }, {
      text = true,
    }):wait()
    if root_result.code ~= 0 then
      return {}
    end

    local root = vim.trim(root_result.stdout)
    local status_result = vim.system({ 'git', '-C', root, 'status', '--porcelain=v1', '-z' }, {
      text = true,
    }):wait()
    if status_result.code ~= 0 then
      return {}
    end

    local status_by_path = {}
    local entries = vim.split(status_result.stdout, '\0', {
      plain = true,
      trimempty = true,
    })
    local index = 1
    while index <= #entries do
      local entry = entries[index]
      if #entry >= 4 then
        local index_status = entry:sub(1, 1)
        local worktree_status = entry:sub(2, 2)
        local path = entry:sub(4)
        local label = git_status_label(index_status, worktree_status)

        if label ~= '' then
          local absolute_path = root .. '/' .. path
          local relative_path = vim.fn.fnamemodify(absolute_path, ':.')
          status_by_path[relative_path] = label
        end

        if index_status == 'R' or index_status == 'C' then
          index = index + 1
        end
      end
      index = index + 1
    end

    return status_by_path
  end

  local function display_with_git_status(display, highlights, status)
    if not status then
      return display, highlights
    end

    local icon_end = display:find(' ', 1, true) or 0
    local inserted = status .. ' '
    local inserted_width = #inserted
    highlights = highlights or {}
    for _, highlight in ipairs(highlights) do
      local range = highlight[1]
      if range[1] >= icon_end then
        range[1] = range[1] + inserted_width
        range[2] = range[2] + inserted_width
      end
    end

    for index = 1, #status do
      local status_start = icon_end + index - 1
      local status_char = status:sub(index, index)
      table.insert(highlights, {
        { status_start, status_start + 1 },
        git_status_highlight_groups[status_char] or 'TelescopeResultsComment',
      })
    end

    return display:sub(1, icon_end) .. inserted .. display:sub(icon_end + 1), highlights
  end

  local function git_status_entry_maker(opts)
    local base_entry_maker = telescope_make_entry.gen_from_file(opts)
    local status_by_path = git_status_by_path()

    return function(line)
      local entry = base_entry_maker(line)
      if not entry then
        return nil
      end

      local base_display = entry.display
      entry.display = function(display_entry)
        local display, highlights = base_display(display_entry)
        return display_with_git_status(display, highlights, status_by_path[display_entry.value])
      end

      return entry
    end
  end

  local function git_status_vimgrep_entry_maker(opts)
    local base_entry_maker = telescope_make_entry.gen_from_vimgrep(opts)
    local status_by_path = git_status_by_path()

    return function(line)
      local entry = base_entry_maker(line)
      if not entry then
        return nil
      end

      local base_display = entry.display
      entry.display = function(display_entry)
        local display, highlights = base_display(display_entry)
        return display_with_git_status(display, highlights, status_by_path[display_entry.filename])
      end

      return entry
    end
  end

  vim.keymap.set('n', '<C-p>', function()
    local opts = floating_picker_options()
    opts.entry_maker = git_status_entry_maker(opts)
    telescope_builtin.find_files(opts)
  end, {
    desc = 'Find files',
    silent = true,
  })
  vim.keymap.set('n', '<C-_>', function()
    local opts = floating_picker_options()
    opts.entry_maker = git_status_vimgrep_entry_maker(opts)
    telescope_builtin.live_grep(opts)
  end, {
    desc = 'Search workspace',
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
      git_modified = '#dbbc7f',
      git_staged = '#a7c080',
      git_deleted = '#e67e80',
      git_renamed = '#7fbbb3',
      git_untracked = '#83c092',
      git_conflict = '#d699b6',
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
      git_modified = '#fabd2f',
      git_staged = '#b8bb26',
      git_deleted = '#fb4934',
      git_renamed = '#83a598',
      git_untracked = '#8ec07c',
      git_conflict = '#d3869b',
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
      git_modified = '#f9e2af',
      git_staged = '#a6e3a1',
      git_deleted = '#f38ba8',
      git_renamed = '#89b4fa',
      git_untracked = '#94e2d5',
      git_conflict = '#cba6f7',
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
      git_modified = '#b58900',
      git_staged = '#859900',
      git_deleted = '#dc322f',
      git_renamed = '#268bd2',
      git_untracked = '#2aa198',
      git_conflict = '#6c71c4',
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
  vim.api.nvim_set_hl(0, 'TelescopeGitModified', { fg = highlights.git_modified, bold = true })
  vim.api.nvim_set_hl(0, 'TelescopeGitStaged', { fg = highlights.git_staged, bold = true })
  vim.api.nvim_set_hl(0, 'TelescopeGitDeleted', { fg = highlights.git_deleted, bold = true })
  vim.api.nvim_set_hl(0, 'TelescopeGitRenamed', { fg = highlights.git_renamed, bold = true })
  vim.api.nvim_set_hl(0, 'TelescopeGitUntracked', { fg = highlights.git_untracked, bold = true })
  vim.api.nvim_set_hl(0, 'TelescopeGitConflict', { fg = highlights.git_conflict, bold = true })

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
