--  For more options, you can see `:help option-list`
vim.g.have_nerd_font = true
vim.g.netrw_banner = 0

local opt = vim.opt

-- See `:help vim.o`
-- Tab / Indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true
opt.wrap = true
opt.breakindent = true -- Enable break indent

-- Search
opt.incsearch = true -- Case-insensitive searching UNLESS \C or capital in search
opt.ignorecase = true
opt.smartcase = true

opt.hlsearch = false -- Set highlight on search

-- Appearance
opt.number = true -- Make line numbers default
opt.relativenumber = true -- Make relative line numbers default

opt.termguicolors = true
opt.cmdheight = 1

opt.scrolloff = 10 -- Minimal number of screen lines to keep above and below the cursor.

opt.completeopt = 'menuone,noinsert,noselect' -- Better completion experience

opt.signcolumn = 'yes' -- Keep signcolumn on by default

opt.list = true -- Sets how neovim will display certain whitespace characters in the editor.
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' } --  See `:help 'list'` and `:help 'listchars'`

-- Behaviour
opt.updatetime = 250 -- Decrease update time
opt.timeoutlen = 300 -- Decrease mapped sequence wait time
opt.hidden = true
opt.errorbells = false
opt.swapfile = false
opt.backup = false
opt.undodir = vim.fn.expand '~/.vim/undodir'
opt.undofile = true -- Save undo history
opt.backspace = 'indent,eol,start'

opt.splitright = true -- Configure how new splits should be opened
opt.splitbelow = true

opt.autochdir = false
opt.iskeyword:append '-'
opt.mouse = 'a' -- Enable mouse mode
opt.clipboard = 'unnamedplus' -- Sync clipboard between OS and Neovim.
opt.modifiable = true
opt.encoding = 'UTF-8'
opt.showmode = false -- Don't show the mode, since it's already in the status line
opt.inccommand = 'split' -- Preview substitutions live
opt.cursorline = true -- Show which line the cursor is on

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.opt.confirm = true

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)
