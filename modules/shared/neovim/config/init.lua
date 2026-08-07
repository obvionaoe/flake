-- ============================================================================
-- init.lua — vendored by ~/.flake (modules/shared/neovim), symlinked to
-- ~/.config/nvim/init.lua by home-manager.
--
-- This is a single file on purpose: it's meant to be read top to bottom,
-- kickstart.nvim-style. There is NO plugin manager here (no lazy.nvim/packer)
-- — every plugin listed in modules/shared/neovim/default.nix is installed by
-- Nix and already on the runtimepath before this file runs. All this file
-- does is set options, keymaps, and call each plugin's setup().
--
-- New to Neovim? Run `:Tutor` (or `vimtutor` from a shell) before editing
-- this file — it's ~30 min and covers the motions everything below assumes.
-- ============================================================================

-- Leader key: must be set before any <leader> keymap below.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- ----------------------------------------------------------------------------
-- Core options
-- ----------------------------------------------------------------------------
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = 'yes' -- reserve space for diagnostic/git signs, avoids text shifting

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true -- case-sensitive only if the search has a capital letter
opt.incsearch = true

opt.splitright = true
opt.splitbelow = true

opt.scrolloff = 8
opt.wrap = false

opt.undofile = true -- persistent undo across sessions
opt.updatetime = 250

-- Share the system clipboard so yank/paste work with other apps.
opt.clipboard = 'unnamedplus'

-- ----------------------------------------------------------------------------
-- Core keymaps
-- (Window navigation across tmux panes is handled by vim-tmux-navigator —
-- installed as a plugin, no config needed, it wires C-h/j/k/l itself.)
-- ----------------------------------------------------------------------------
local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })
map('n', '<leader>w', '<cmd>write<CR>', { desc = 'Save file' })
map('n', '<leader>q', '<cmd>quit<CR>', { desc = 'Quit window' })

map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic' })

-- ----------------------------------------------------------------------------
-- which-key — shows available keybindings in a popup as you type a prefix.
-- This is the "live cheatsheet": it reads your actual mappings, so it can
-- never go stale the way a hand-written cheatsheet file would.
-- ----------------------------------------------------------------------------
require('which-key').setup({})
require('which-key').add({
  { '<leader>f', group = 'find' },
  { '<leader>l', group = 'lsp' },
})

-- ----------------------------------------------------------------------------
-- Treesitter — accurate, parser-based syntax highlighting/indent.
-- Grammars are installed by Nix (see the withPlugins list in default.nix),
-- so this only needs to *start* the highlighter per filetype, not install
-- anything.
-- ----------------------------------------------------------------------------
local ts_filetypes = {
  'nix', 'lua', 'go', 'gomod', 'gowork', 'gosum',
  'bash', 'markdown', 'markdown_inline', 'yaml', 'toml', 'json', 'vim', 'vimdoc',
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = ts_filetypes,
  callback = function()
    vim.treesitter.start()
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

-- ----------------------------------------------------------------------------
-- Completion (blink.cmp)
-- ----------------------------------------------------------------------------
require('blink.cmp').setup({
  keymap = { preset = 'default' }, -- Ctrl-y accept, Ctrl-n/p or arrows to move
  sources = {
    default = { 'lsp', 'path', 'buffer' },
  },
  signature = { enabled = true },
})

-- ----------------------------------------------------------------------------
-- LSP — native Neovim 0.11+ API (vim.lsp.config/vim.lsp.enable). Server
-- default configs are supplied by nvim-lspconfig just by being on the
-- runtimepath (it ships lsp/<name>.lua files nvim autoloads) — no
-- `require('lspconfig')` call needed.
-- ----------------------------------------------------------------------------
vim.lsp.config('*', {
  capabilities = require('blink.cmp').get_lsp_capabilities(),
})

vim.lsp.config('lua_ls', {
  settings = { Lua = { diagnostics = { globals = { 'vim' } } } },
})

vim.lsp.enable({ 'nixd', 'gopls', 'lua_ls', 'ts_ls' })

-- Buffer-local LSP keymaps, only once a server actually attaches.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    local opts = { buffer = event.buf }
    map('n', 'gd', vim.lsp.buf.definition, vim.tbl_extend('force', opts, { desc = 'Go to definition' }))
    map('n', 'gr', vim.lsp.buf.references, vim.tbl_extend('force', opts, { desc = 'Go to references' }))
    map('n', 'K', vim.lsp.buf.hover, vim.tbl_extend('force', opts, { desc = 'Hover docs' }))
    map('n', '<leader>lr', vim.lsp.buf.rename, vim.tbl_extend('force', opts, { desc = 'Rename symbol' }))
    map('n', '<leader>la', vim.lsp.buf.code_action, vim.tbl_extend('force', opts, { desc = 'Code action' }))
  end,
})

-- ----------------------------------------------------------------------------
-- Telescope — fuzzy finder for files, live grep, buffers, LSP references.
-- Uses fd/ripgrep as backends (installed system-wide by modules/shared/search).
-- ----------------------------------------------------------------------------
require('telescope').setup({})

local telescope_builtin = require('telescope.builtin')
map('n', '<leader>ff', telescope_builtin.find_files, { desc = 'Find files' })
map('n', '<leader>fg', telescope_builtin.live_grep, { desc = 'Grep project' })
map('n', '<leader>fb', telescope_builtin.buffers, { desc = 'Find buffers' })
map('n', '<leader>fh', telescope_builtin.help_tags, { desc = 'Help tags' })

-- ----------------------------------------------------------------------------
-- Statusline + colorscheme
-- ----------------------------------------------------------------------------
require('lualine').setup({
  options = { theme = 'tokyonight' },
})

vim.cmd.colorscheme('tokyonight')
