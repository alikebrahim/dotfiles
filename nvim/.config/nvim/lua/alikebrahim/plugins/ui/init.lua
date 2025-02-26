-- UI plugins
return {
  -- Color scheme
  { import = 'alikebrahim.plugins.ui.kanagawa' },
  
  -- UI helpers
  { import = 'alikebrahim.plugins.ui.which-key' },
  { import = 'alikebrahim.plugins.ui.gitsigns' },
  { import = 'alikebrahim.plugins.ui.todo-comments' },
  { import = 'alikebrahim.plugins.ui.mini' },
  { import = 'alikebrahim.plugins.ui.indent-blankline' },
  
  -- Sleuth detects indentation
  'tpope/vim-sleuth',
}