return {
  'petertriho/nvim-scrollbar',
  dependencies = { 'lewis6991/gitsigns.nvim' },
  event = 'VeryLazy',
  config = function()
    require('scrollbar').setup {
      handlers = {
        gitsigns = true,
      },
      -- Default marks use thin "-"/"=" characters at 30% blend, which get
      -- lost against the background. The scrollbar column itself is always
      -- exactly 1 char wide (no "width" setting exists), so making
      -- diagnostics/gitsigns visible means making the marks themselves
      -- bolder instead -- solid blocks at full opacity.
      handle = {
        blend = 0,
      },
      -- Every mark uses the same solid full-block glyph (max size/opacity),
      -- relying entirely on color to distinguish them -- so no two mark
      -- colors may collide. GitSignsDelete (#ee5396) is otherwise identical
      -- to DiagnosticVirtualTextError under tokyo-night; override just the
      -- scrollbar's GitDelete color (doesn't touch the real GitSignsDelete
      -- highlight used elsewhere) so it's distinct from Error.
      marks = {
        Error = { text = { '█' } },
        Warn = { text = { '█' } },
        Info = { text = { '█' } },
        Hint = { text = { '█' } },
        GitAdd = { text = '█' },
        GitChange = { text = '█' },
        GitDelete = { text = '█', color = '#ff9e64' },
      },
    }
    require('scrollbar.handlers.gitsigns').setup()
  end,
}
