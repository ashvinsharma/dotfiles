return {
  'akinsho/bufferline.nvim',
  dependencies = 'nvim-tree/nvim-web-devicons',

  config = function()
    local bufferline = require 'bufferline'

    bufferline.setup {
      options = {
        diagnostics = 'nvim_lsp',
        hover = { enabled = true, delay = 50, reveal = { 'close' } },
        style_preset = {
          bufferline.style_preset.no_bold,
          bufferline.style_preset.no_italic,
        },
        offsets = {
          {
            -- text = 'File Explorer',
            highlight = 'Directory',
            separator = true,
            filetype = 'neo-tree',
          },
        },
      },
    }
  end,
}
