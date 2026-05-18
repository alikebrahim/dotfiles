-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
local opt = vim.opt
opt.breakindent = true
opt.wrap = true
opt.clipboard = "unnamedplus"
vim.g.python3_host_prog = vim.fn.expand("~/.local/share/nvim/python-provider/bin/python")
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
