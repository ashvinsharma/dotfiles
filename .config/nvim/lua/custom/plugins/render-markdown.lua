return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown' },
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
  opts = {},
  config = function()
    require('render-markdown').setup {
      checkbox = {
        checked = {
          icon = '✓',
        },
        custom = {
          todo = {
            raw = '[-]',
            rendered = '⏲︎',
          },
        },
      },
    }
  end,
}
