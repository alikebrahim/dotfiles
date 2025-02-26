-- Vim-go for Go language support
return {
  'fatih/vim-go',
  ft = { 'go' },
  build = ':GoUpdateBinaries',
}