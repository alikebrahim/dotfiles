-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local keymap = vim.keymap
local api = vim.api
local opts = { noremap = true, silent = true }

-- [[ Basic Keymaps ]]

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Move lines in visual mode
keymap.set("v", "K", ":m '<-2<CR>gv=gv")
keymap.set("v", "J", ":m '>+1<CR>gv=gv")

-- Comments
api.nvim_set_keymap("n", "<C-/>", "gcc", { noremap = false })
api.nvim_set_keymap("v", "<C-/>", "gcc", { noremap = false })
api.nvim_set_keymap("x", "<C-/>", "gcc<C-c>", { noremap = false })

-- Macros
keymap.set("n", "Q", "@qj")
keymap.set("x", "Q", ":norm @q<Return>")

-- [[ Remap from devaslife ]]
-- throw away x delete
-- keymap.set('n', 'x', '"_x')

-- increament and decreament digits
keymap.set("n", "+", "<C-a>")
keymap.set("n", "-", "<C-x>")

-- select all document
-- API-based to avoid snacks.scroll animating the cursor back mid-selection
keymap.set("n", "<leader>a", function()
  local last = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("normal! V")
  vim.api.nvim_win_set_cursor(0, { last, 0 })
end, { desc = "Select all" })

-- Split Window
keymap.set("n", "ss", ":split<Return>", opts)
keymap.set("n", "sv", ":vsplit<Return>", opts)

-- Resize Window
keymap.set("n", "<C-w>l", "<C-w>>", opts)
keymap.set("n", "<C-w>h", "<C-w><", opts)
keymap.set("n", "<C-w>j", "<C-w>-", opts)
keymap.set("n", "<C-w>k", "<C-w>+", opts)
-- [[ end devaslife ]]

-- [[ Remap from thePrimagen ]]
-- netrw
keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "netrw" })

-- Center search
api.nvim_set_keymap("n", "n", "nzzzv", { noremap = true })
api.nvim_set_keymap("n", "N", "Nzzzv", { noremap = true })
api.nvim_set_keymap("n", "*", "*zzzv", { noremap = true })

-- Persist yanked in _ buffer
api.nvim_set_keymap("x", "<leader>p", '"_dP', { noremap = true, silent = true })
-- [[ end thePrimagen ]]
