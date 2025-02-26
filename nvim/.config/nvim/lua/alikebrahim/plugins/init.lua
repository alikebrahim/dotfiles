-- Main plugin entry point
return {
  -- UI and appearance
  { import = 'alikebrahim.plugins.ui' },
  
  -- Editor enhancements
  { import = 'alikebrahim.plugins.editor' },
  
  -- LSP configuration
  { import = 'alikebrahim.plugins.lsp' },
  
  -- Completion
  { import = 'alikebrahim.plugins.completion' },
  
  -- Navigation
  { import = 'alikebrahim.plugins.navigation' },
  
  -- Development tools
  { import = 'alikebrahim.plugins.tools' },
  
  -- Import kickstart plugins
  { import = 'kickstart.plugins' },
}