return {
  'm4xshen/hardtime.nvim',
  lazy = false,
  dependencies = { 'MunifTanjim/nui.nvim' },
  opts = {
    -- Default is 3 -- way too strict for normal scrolling through code.
    -- Applies to all restricted_keys (h/j/k/l and a few others), not just
    -- j/k specifically -- hardtime has no per-key threshold.
    max_count = 20,
  },
}
