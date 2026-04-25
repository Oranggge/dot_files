let mapleader = " "

call plug#begin()

" List your plugins here
Plug 'tpope/vim-sensible'
Plug 'karb94/neoscroll.nvim'
Plug 'morhetz/gruvbox'

" Navigation
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-tree/nvim-tree.lua'
Plug 'akinsho/bufferline.nvim', { 'tag': 'v4.*' }
" Pinned to v0.10.0 — main branch requires Neovim 0.12+, unpin when Fedora ships 0.12
Plug 'nvim-treesitter/nvim-treesitter', { 'tag': 'v0.10.0', 'do': ':TSUpdate' }
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
Plug 'folke/which-key.nvim'
Plug 'lewis6991/gitsigns.nvim'
Plug 'lukas-reineke/indent-blankline.nvim'
Plug 'sindrets/diffview.nvim'
Plug 'folke/trouble.nvim'
Plug 'MeanderingProgrammer/render-markdown.nvim'

call plug#end()

" Gruvbox colorscheme
set background=dark
set termguicolors
colorscheme gruvbox

lua << EOF
require('neoscroll').setup({})

-- File explorer
require('nvim-tree').setup({
  view = { width = 30 },
  filters = { dotfiles = false },
  update_focused_file = { enable = true },
})

-- Bufferline (tabs)
require('bufferline').setup({
  options = {
    diagnostics = false,
    show_buffer_close_icons = true,
    show_close_icon = false,
    separator_style = "slant",
    offsets = {
      { filetype = "NvimTree", text = "Explorer", text_align = "center" },
    },
  },
})

-- Telescope
local actions = require('telescope.actions')
local action_layout = require('telescope.actions.layout')
require('telescope').setup({
  defaults = {
    file_ignore_patterns = { "node_modules", ".git/" },
    mappings = {
      i = {
        ["<C-/>"] = action_layout.toggle_preview,
        ["<C-p>"] = action_layout.cycle_layout_next,
      },
      n = {
        ["<C-/>"] = action_layout.toggle_preview,
        ["<C-p>"] = action_layout.cycle_layout_next,
      },
    },
    layout_strategy = "vertical",
    layout_config = {
      horizontal = { preview_width = 0.55 },
    },
    cycle_layout_list = { "horizontal", "vertical" },
  },
})

-- Trouble (unified panel for diagnostics, references, symbols, call hierarchy)
require('trouble').setup({
  modes = {
    lsp_references = {
      -- Sort order for `gr`: current file first, test/spec files last, then
      -- alphabetical by filename and natural line/col order.
      sort = {
        { buf = 0 },
        function(item)
          local f = (item.filename or ""):lower()
          local is_test = f:match("[/._-]tests?[/._-]")
              or f:match("[/._-]spec[/._-]")
              or f:match("%.test%.")
              or f:match("%.spec%.")
          return is_test and 1 or 0
        end,
        "filename",
        "pos",
      },
    },
  },
})

-- Which-key
local wk = require('which-key')
wk.setup()
wk.add({
  { "<leader>f", group = "Find" },
  { "<leader>ff", desc = "Find files" },
  { "<leader>fg", desc = "Live grep" },
  { "<leader>fw", desc = "Find word under cursor" },
  { "<leader>fb", desc = "Find buffers" },
  { "<leader>fh", desc = "Find help" },
  { "<leader>e", desc = "Toggle explorer" },
  { "<leader>h", desc = "Jump to explorer" },
  { "<leader>l", desc = "Jump to editor" },
  { "<leader>x", desc = "Close buffer" },
  { "<leader>t", group = "Trouble" },
  { "<leader>tt", desc = "Workspace diagnostics" },
  { "<leader>tb", desc = "Buffer diagnostics" },
  { "<leader>ts", desc = "Symbols outline" },
  { "<leader>tr", desc = "LSP references" },
  { "<leader>td", desc = "LSP definitions" },
  { "<leader>ti", desc = "LSP implementations" },
  { "<leader>rn", desc = "Rename symbol" },
  { "<leader>ca", desc = "Code actions" },
  { "<leader>D", desc = "Delete + yank" },
  { "<leader>Y", desc = "Delete to clipboard" },
  { "gd", desc = "Go to definition" },
  { "gr", desc = "Go to references" },
  { "gi", desc = "Go to implementation" },
  { "gf", desc = "Next function" },
  { "gF", desc = "Prev function" },
  { "gc", desc = "Next class" },
  { "gC", desc = "Prev class" },
  { "ge", desc = "Next error" },
  { "gE", desc = "Prev error" },
  { "<leader>g", group = "Git" },
  { "<leader>gp", desc = "Preview hunk" },
  { "<leader>gb", desc = "Blame line" },
  { "<leader>gd", desc = "Diff file" },
  { "<leader>gg", desc = "Lazygit" },
  { "<leader>gv", desc = "Diffview open" },
  { "<leader>gc", desc = "Diffview close" },
  { "<leader>gl", desc = "Diffview file history" },
})

-- Gitsigns
require('gitsigns').setup({
  signs = {
    add          = { text = '│' },
    change       = { text = '│' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
  },
  current_line_blame = true,
  on_attach = function(bufnr)
    local gs = require('gitsigns')
    local opts = { buffer = bufnr }
    vim.keymap.set('n', ']g', gs.next_hunk, opts)
    vim.keymap.set('n', '[g', gs.prev_hunk, opts)
    vim.keymap.set('n', '<leader>gp', gs.preview_hunk, opts)
    vim.keymap.set('n', '<leader>gb', gs.blame_line, opts)
    vim.keymap.set('n', '<leader>gd', gs.diffthis, opts)
  end,
})

-- Diffview
require('diffview').setup({})
vim.keymap.set('n', '<leader>gv', '<cmd>DiffviewOpen<cr>', { desc = 'Diffview open' })
vim.keymap.set('n', '<leader>gc', '<cmd>DiffviewClose<cr>', { desc = 'Diffview close' })
vim.keymap.set('n', '<leader>gl', '<cmd>DiffviewFileHistory %<cr>', { desc = 'Diffview file history' })

-- Lazygit (opens in a floating terminal)
vim.keymap.set('n', '<leader>gg', function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = math.floor(vim.o.columns * 0.9),
    height = math.floor(vim.o.lines * 0.9),
    col = math.floor(vim.o.columns * 0.05),
    row = math.floor(vim.o.lines * 0.05),
    style = 'minimal',
    border = 'rounded',
  })
  vim.fn.termopen('lazygit', { on_exit = function() vim.api.nvim_buf_delete(buf, { force = true }) end })
  vim.cmd('startinsert')
end, { desc = 'Lazygit' })

-- Render markdown inline (headings, code blocks, bullets, tables, checkboxes)
require('render-markdown').setup({})

-- In markdown buffers, <CR> follows the link under the cursor:
--   [text](path.md)  → :edit path.md (resolved relative to current file)
--   [text](https://) → opens in system browser via vim.ui.open
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  callback = function()
    vim.keymap.set('n', '<CR>', function()
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2] + 1
      local start = 1
      while true do
        local s, e, target = line:find('%[[^%]]*%]%(([^%)]+)%)', start)
        if not s then return end
        if col >= s and col <= e then
          if target:match('^%w+://') then
            vim.ui.open(target)
          else
            target = target:gsub('#.*$', '')
            local dir = vim.fn.expand('%:p:h')
            vim.cmd('edit ' .. vim.fn.fnameescape(dir .. '/' .. target))
          end
          return
        end
        start = e + 1
      end
    end, { buffer = true, desc = 'Follow markdown link' })
  end,
})

-- Indent guides
require('ibl').setup({
  indent = { char = '│' },
  scope = { enabled = true, show_start = false, show_end = false },
})

-- Enable treesitter highlighting for all supported filetypes
vim.api.nvim_create_autocmd('FileType', {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

-- Treesitter textobjects
require('nvim-treesitter-textobjects').setup({ move = { set_jumps = true } })
local move = require('nvim-treesitter-textobjects.move')

vim.keymap.set({ 'n', 'x' }, 'gf', function() move.goto_next_start('@function.outer') end, { desc = 'Go to next function' })
vim.keymap.set({ 'n', 'x' }, 'gF', function() move.goto_previous_start('@function.outer') end, { desc = 'Go to prev function' })
vim.keymap.set({ 'n', 'x' }, 'gc', function() move.goto_next_start('@class.outer') end, { desc = 'Go to next class' })
vim.keymap.set({ 'n', 'x' }, 'gC', function() move.goto_previous_start('@class.outer') end, { desc = 'Go to prev class' })

-- LSP setup
local on_attach = function(client, bufnr)
  local opts = { buffer = bufnr }
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
  vim.keymap.set('n', 'gr', '<cmd>Trouble lsp_references toggle focus=true<cr>', opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('n', 'ge', vim.diagnostic.goto_next, opts)
  vim.keymap.set('n', 'gE', vim.diagnostic.goto_prev, opts)
end

-- Rust
vim.lsp.start = vim.lsp.start
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'rust',
  callback = function()
    vim.lsp.start({
      name = 'rust-analyzer',
      cmd = { 'rust-analyzer' },
      root_dir = vim.fs.root(0, { 'Cargo.toml', 'rust-project.json' }),
      on_attach = on_attach,
    })
  end,
})

-- TypeScript / Angular
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact', 'html' },
  callback = function()
    local root = vim.fs.root(0, { 'angular.json', 'tsconfig.json', 'package.json' })
    local is_angular = root and vim.fn.filereadable(root .. '/angular.json') == 1

    if is_angular then
      -- Derive the global node_modules from whatever `node` PATH resolves
      -- to, so this stays correct across nvm upgrades.
      local node_prefix = vim.fn.fnamemodify(vim.fn.exepath('node'), ':h:h')
      vim.lsp.start({
        name = 'angularls',
        cmd = { 'ngserver', '--stdio', '--tsProbeLocations', root .. '/node_modules', '--ngProbeLocations', node_prefix .. '/lib/node_modules' },
        root_dir = root,
        on_attach = function(client, bufnr)
          -- ts_ls handles these for .ts files; silence angularls to avoid duplicate results.
          client.server_capabilities.referencesProvider = false
          client.server_capabilities.definitionProvider = false
          client.server_capabilities.implementationProvider = false
          client.server_capabilities.renameProvider = false
          client.server_capabilities.hoverProvider = false
          on_attach(client, bufnr)
        end,
      })
    end

    vim.lsp.start({
      name = 'ts_ls',
      cmd = { 'typescript-language-server', '--stdio' },
      root_dir = root,
      on_attach = on_attach,
    })
  end,
})
EOF

" Folding with treesitter
set foldmethod=expr
set foldexpr=v:lua.vim.treesitter.foldexpr()
set foldlevel=99
set foldcolumn=1

" jj to exit insert mode
inoremap jj <Esc>

" Clear search highlight with Esc
nnoremap <Esc> <cmd>noh<cr>

" --- Keybindings ---
" Telescope
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fw <cmd>Telescope grep_string<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>

" Nvim-tree
nnoremap <leader>e <cmd>NvimTreeToggle<cr>
nnoremap <leader>h <cmd>NvimTreeFocus<cr>
nnoremap <leader>l <cmd>wincmd l<cr>

" Bufferline — navigate tabs
nnoremap <Tab> <cmd>BufferLineCycleNext<cr>
nnoremap <S-Tab> <cmd>BufferLineCyclePrev<cr>
nnoremap <leader>x <cmd>bd<cr>

" --- Trouble (unified panel) ---
" tt workspace diagnostics    tb buffer diagnostics   ts symbols outline
" tr LSP references           td definitions          ti implementations
nnoremap <leader>tt <cmd>Trouble diagnostics toggle<cr>
nnoremap <leader>tb <cmd>Trouble diagnostics toggle filter.buf=0<cr>
nnoremap <leader>ts <cmd>Trouble symbols toggle focus=false win.position=right win.size=50<cr>
nnoremap <leader>tr <cmd>Trouble lsp_references toggle focus=true<cr>
nnoremap <leader>td <cmd>Trouble lsp_definitions toggle focus=true<cr>
nnoremap <leader>ti <cmd>Trouble lsp_implementations toggle focus=true<cr>


" ignore case search, set number, and copy copy to clipboard
set ignorecase
set number
set clipboard=unnamedplus

" keep cursor vertically centered — screen scrolls around it
set scrolloff=999
" --- Delete / change without yanking (Neovim init.vim) ---

" Delete (normal + visual) — never touch unnamed register
nnoremap d "_d
nnoremap D "_D
nnoremap dd "_dd
xnoremap d "_d

" Character delete
nnoremap x "_x
nnoremap X "_X
xnoremap x "_x

" Change (replaces text) — also without yanking
nnoremap c "_c
nnoremap C "_C
xnoremap c "_c

" Substitute single char (like 'cl')
nnoremap s "_s
nnoremap S "_S
xnoremap s "_s

" --- Optional quality-of-life: quick way to *do* a yanky delete when you want it ---
" <leader>D in normal/visual will delete *and* yank (into the default register)
nnoremap <leader>D d
xnoremap <leader>D d

" If you sometimes want delete->system clipboard explicitly:
" <leader>Y deletes to + register (system clipboard)
nnoremap <leader>Y "+d
xnoremap <leader>Y "+d

" Notes:
" 1) With the remaps above, all your d/x/c/s go to the black-hole register.
" 2) To force a one-off yanky delete with registers, you can also type: ""d  (double quote then d)
" 3) Yank commands (y, yy, Y) are untouched and still fill the unnamed/clipboard registers normally.

" <leader>yy — yank current file's absolute path to system clipboard
nnoremap <leader>yy :let @+=expand('%:p')<CR>:echo 'copied: ' . expand('%:p')<CR>

