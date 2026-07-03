return {
  'rcarriga/nvim-notify',
  init = function()
    -- Lazily require so this works even for notifications fired before the
    -- plugin object has fully loaded/applied opts.
    vim.notify = function(...)
      return require('notify')(...)
    end
  end,
  opts = function()
    local colors = require 'custom.colors'
    return {
      -- Explicit background: Normal is transparent (see nightfox.lua), and
      -- notify windows blend against 'Normal' by default, which would
      -- otherwise show through to the terminal background inconsistently.
      background_colour = colors.surface0,
      timeout = 3000,
      top_down = true,
      stages = 'fade_in_slide_out',
      render = 'compact',
      max_width = 80,
    }
  end,
}
