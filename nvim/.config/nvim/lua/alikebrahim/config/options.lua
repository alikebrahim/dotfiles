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
--
-- Appearance
opt.number = true -- Make line numbers default
opt.relativenumber = true -- Make relative line numbers default
opt.termguicolors = true
opt.cmdheight = 1
opt.scrolloff = 10
opt.completeopt = 'menuone,noinsert,noselect' -- Better completion experience
opt.signcolumn = 'yes' -- Keep signcolumn on by default
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Behaviour
opt.updatetime = 250 -- Decrease update time
opt.timeoutlen = 300
opt.hidden = true
opt.errorbells = false
opt.swapfile = false
opt.backup = false
opt.undodir = vim.fn.expand '~/.vim/undodir'
opt.undofile = true -- Save undo history
opt.backspace = 'indent,eol,start'
opt.splitright = true
opt.splitbelow = true
opt.autochdir = false
opt.iskeyword:append '-'
opt.mouse = 'a' -- Enable mouse mode
opt.clipboard = 'unnamedplus' -- Sync clipboard between OS and Neovim.
opt.modifiable = true
opt.encoding = 'UTF-8'
opt.showmode = false
opt.inccommand = 'split' -- Preview substitutions live
opt.cursorline = false -- Show which line the cursor is on
