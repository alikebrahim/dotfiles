return {
  {
    "mrcjkb/rustaceanvim",
    -- Directly set vim.g.rustaceanvim after LazyVim's config has run.
    -- Using config() instead of opts() because the LazyVim extra's config
    -- function runs before our opts are merged, so opts-based merge is lost.
    config = function()
      local ra = vim.g.rustaceanvim
      if ra and ra.server and ra.server.default_settings then
        local rs = ra.server.default_settings["rust-analyzer"]
        -- Override checkOnSave: we DO want rust-analyzer to run clippy,
        -- even though bacon-ls handles diagnostics separately.
        rs.checkOnSave = true
        rs.check = { command = "clippy" }
        -- Enable diagnostics from rust-analyzer too (bacon-ls is additive)
        rs.diagnostics = { enable = true }
        -- Inlay hints
        rs.inlayHints = {
          bindingModeHints = { enable = true },
          closureReturnTypeHints = { enable = "always" },
          lifetimeElisionHints = { enable = "always" },
          discriminantHints = { enable = "always" },
        }
      end
    end,
  },
}
