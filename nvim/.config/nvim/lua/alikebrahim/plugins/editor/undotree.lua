-- Undotree for visualizing the undo history
return {
  'mbbill/undotree',
  config = function()
    vim.keymap.set('n', '<leader>ut', vim.cmd.UndotreeToggle, { desc = 'Undotree Toggle' })
  end,
}