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
          -- carbonfox's default DiagnosticWarn is purple (#be95ff), which
          -- reads as neither "warning" nor consistent with the standard
          -- error=red/warning=yellow/info=blue convention this theme
          -- otherwise already follows (Error #ee5396, Info #78a9ff).
          -- DiagnosticFloatingWarn/DiagnosticSignWarn link to
          -- DiagnosticWarn so overriding it covers those too;
          -- VirtualText/Underline are set independently and need their own
          -- override.
          DiagnosticWarn = { fg = '#e5c07b' },
          DiagnosticVirtualTextWarn = { fg = '#e5c07b', bg = '#322e29' },
          DiagnosticUnderlineWarn = { style = 'undercurl', sp = '#e5c07b' },
        },
      },
    }
    vim.cmd.colorscheme 'carbonfox'
  end,
}
