return {
  'EdenEast/nightfox.nvim',
  priority = 1000,
  config = function()
    local colors = require 'custom.colors'
    require('nightfox').setup {
      options = {
        transparent = true,
      },
      groups = {
        all = {
          NormalFloat = { bg = colors.surface0 },
          FloatBorder = { bg = colors.surface0, fg = colors.overlay0 },
          FloatTitle = { bg = colors.surface0, fg = colors.fg },
        },
      },
    }
    vim.cmd.colorscheme 'nordfox'
  end,
}
