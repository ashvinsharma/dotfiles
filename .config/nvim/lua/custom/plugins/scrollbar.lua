return {
  'petertriho/nvim-scrollbar',
  dependencies = { 'lewis6991/gitsigns.nvim' },
  event = 'VeryLazy',
  config = function()
    require('scrollbar').setup {
      handlers = {
        gitsigns = true,
      },
    }
    require('scrollbar.handlers.gitsigns').setup()
  end,
}
