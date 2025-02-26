-- Harpoon for quick file navigation
return {
  'ThePrimeagen/harpoon',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  branch = 'harpoon2',
  config = function()
    local harpoon = require 'harpoon'
    harpoon:setup {
      settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
        key = function()
          return vim.loop.cwd()
        end,
      },
    }

    -- Keymaps
    vim.keymap.set('n', '<leader>ha', function()
      harpoon:list():append()
    end, { desc = 'Harpoon add file' })

    vim.keymap.set('n', '<leader>he', function()
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = 'Harpoon quick menu' })

    -- Navigation shortcuts
    vim.keymap.set('n', '<C-j>', function()
      harpoon:list():select(1)
    end, { desc = 'Harpoon to file 1' })
    vim.keymap.set('n', '<C-k>', function()
      harpoon:list():select(2)
    end, { desc = 'Harpoon to file 2' })
    vim.keymap.set('n', '<C-l>', function()
      harpoon:list():select(3)
    end, { desc = 'Harpoon to file 3' })
    vim.keymap.set('n', '<C-;>', function()
      harpoon:list():select(4)
    end, { desc = 'Harpoon to file 4' })
  end,
}