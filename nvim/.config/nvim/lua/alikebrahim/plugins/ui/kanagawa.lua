-- Kanagawa colorscheme configuration
return {
  'rebelot/kanagawa.nvim',
  priority = 1000, -- Make sure to load this before all the other start plugins
  config = function()
    require('kanagawa').setup {
      compile = false, -- Enable compiling the colorscheme
      undercurl = true, -- Enable undercurls
      commentStyle = { italic = true },
      functionStyle = {},
      keywordStyle = { italic = true },
      statementStyle = { bold = true },
      typeStyle = {},
      transparent = false, -- Set background color
      dimInactive = false, -- Dim inactive windows
      terminalColors = true, -- Define vim.g.terminal_color_{0,17}
      colors = { -- Add/modify theme and palette colors
        palette = {},
        theme = {
          wave = {
            comment = '#1bc449', -- Set comments to green in the wave theme
          },
          lotus = {},
          dragon = {},
          all = {},
        },
      },
      overrides = function(colors) -- Add/modify highlights
        return {
          Comment = { fg = '#1bc449' }, -- Ensure comments are green
        }
      end,
      theme = 'wave', -- Load "wave" theme when 'background' option is not set
      background = { -- Map the value of 'background' option to a theme
        dark = 'wave', -- When set to 'dark', load the 'wave' theme
        light = 'lotus', -- When set to 'light', load the 'lotus' theme
      },
    }
    vim.cmd.colorscheme 'kanagawa'
  end,
}
