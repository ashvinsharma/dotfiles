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
      -- Every mark keeps its real highlight color (DiagnosticVirtualText*/
      -- GitSigns*) unmodified, so the scrollbar always matches the actual
      -- gutter/virtual-text colors elsewhere -- a mismatched color here
      -- would be more confusing than helpful. Solid full-block glyph for
      -- max size/opacity. GitSignsDelete (#ee5396) happens to be identical
      -- to DiagnosticVirtualTextError under tokyo-night, so that one pair
      -- gets a distinct shape instead of a fake color to tell them apart.
      marks = {
        Error = { text = { '█' } },
        Warn = { text = { '█' } },
        Info = { text = { '█' } },
        Hint = { text = { '█' } },
        GitAdd = { text = '█' },
        GitChange = { text = '█' },
        GitDelete = { text = '▄' },
      },
    }
    require('scrollbar.handlers.gitsigns').setup()
  end,
}
