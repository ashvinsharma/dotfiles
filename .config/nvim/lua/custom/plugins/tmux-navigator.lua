return {
  'christoomey/vim-tmux-navigator',
  lazy = false,
  init = function()
    -- We define our own keys below via lazy.nvim's `keys`, so disable the
    -- plugin's own default mappings to avoid double-binding.
    vim.g.tmux_navigator_no_mappings = 1
  end,
  keys = {
    { '<C-h>', '<cmd>TmuxNavigateLeft<CR>', desc = 'Move focus to the left window/pane' },
    { '<C-j>', '<cmd>TmuxNavigateDown<CR>', desc = 'Move focus to the lower window/pane' },
    { '<C-k>', '<cmd>TmuxNavigateUp<CR>', desc = 'Move focus to the upper window/pane' },
    { '<C-l>', '<cmd>TmuxNavigateRight<CR>', desc = 'Move focus to the right window/pane' },
    { '<C-\\>', '<cmd>TmuxNavigatePrevious<CR>', desc = 'Move focus to the previous window/pane' },
  },
}
