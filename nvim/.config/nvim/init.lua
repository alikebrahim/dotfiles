-- Set leader key to space
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Core Neovim configuration
require 'alikebrahim.core.options'
require 'alikebrahim.core.keymaps'
require 'alikebrahim.core.autocmds'

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
end
vim.opt.rtp:prepend(lazypath)

-- Initialize plugins
require('lazy').setup({
  -- Load all plugins through modular configuration
  { import = 'alikebrahim.plugins' },
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- Python path configuration
vim.g.python3_host_prog = '/home/alikebrahim/.pyenv/versions/3.10.12/envs/nvim/bin/python'

-- vim: ts=2 sts=2 sw=2 et

