-- Tools for development
return {
  -- Treesitter for syntax highlighting
  { import = 'alikebrahim.plugins.tools.treesitter' },
  
  -- Go language support
  { import = 'alikebrahim.plugins.tools.vim-go' },
  
  -- Zen mode for distraction-free coding
  { import = 'alikebrahim.plugins.tools.zenmode' },
  
  -- AI assistance with Copilot
  { import = 'alikebrahim.plugins.tools.copilot' },
  
  -- Better diagnostics display with Trouble
  { import = 'alikebrahim.plugins.tools.trouble' },
  
  -- Debugging support
  { import = 'alikebrahim.plugins.tools.debug' },
}