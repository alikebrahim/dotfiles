-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "markdown.mdx" },
  callback = function(args)
    vim.diagnostic.enable(false, { bufnr = args.buf })
  end,
})

-- Fix broken yank highlight on nvim 0.13 nightly (vim.hl.hl_op doesn't exist yet)
vim.api.nvim_del_augroup_by_name("lazyvim_highlight_yank")
vim.api.nvim_create_augroup("lazyvim_highlight_yank", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = "lazyvim_highlight_yank",
  callback = function()
    (vim.hl or vim.highlight).on_yank()
  end,
})
