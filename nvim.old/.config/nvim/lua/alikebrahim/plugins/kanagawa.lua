local config = function()
  require('kanagawa').setup {
    compile = false, -- enable compiling the colorscheme
    undercurl = true, -- enable undercurls
    commentStyle = { fg = '#1f9443', italic = true },
    functionStyle = {},
    keywordStyle = { italic = true },
    statementStyle = { bold = true },
    typeStyle = {},
    transparent = true, -- do not set background color
    dimInactive = false, -- dim inactive window `:h hl-NormalNC`
    terminalColors = true, -- define vim.g.terminal_color_{0,17}
    colors = {
      theme = {
        all = {
          ui = {
            bg_gutter = 'none',
          },
        },
      },
    },
    overrides = function(colors)
      return {}
    end,
    theme = 'dragon', -- Load "wave" theme when 'background' option is not set
    -- background = {     -- map the value of 'background' option to a theme
    --     dark = "wave", -- try "dragon" !
    --     light = "lotus"
    -- },
  }
  vim.cmd 'colorscheme kanagawa'
end
return {
  'rebelot/kanagawa.nvim',
  priority = 1000,
  config = config,
}
