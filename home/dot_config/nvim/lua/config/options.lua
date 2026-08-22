-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
local opt = vim.opt

local is_remote = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil

if is_remote then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = function()
        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
      end,
      ["*"] = function()
        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
      end,
    },
  }
end

vim.g.lazyvim_rust_diagnostics = "bacon-ls"

opt.breakindent = true
opt.wrap = true
opt.clipboard = "unnamedplus"
vim.g.python3_host_prog = vim.fn.expand("~/.local/share/nvim/python-provider/bin/python")
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
