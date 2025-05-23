return {
  'windwp/nvim-ts-autotag',
  config = function()
    require('nvim-ts-autotag').setup {
      filetypes = {
        'glimmer',
        'handlebars',
        'hbs',
        'html',
        'javascript',
        'javascriptreact',
        'jsx',
        'rescript',
        'svelte',
        'tsx',
        'typescript',
        'typescriptreact',
        'vue',
        'xml',
      },
    }
  end,
}
