return {
  'folke/edgy.nvim',
  event = 'VeryLazy',
  init = function()
    -- Required by edgy for windows to resize correctly when a sibling
    -- in the same edge closes.
    vim.opt.laststatus = 3
    vim.opt.splitkeep = 'screen'
  end,
  opts = {
    -- Default true: closes the whole edgebar when every view in it is
    -- "hidden". Off, so closing one docked view (e.g. Explorer) doesn't
    -- take the sibling view (Blame) down with it.
    close_when_all_hidden = false,
    left = {
      { ft = 'neo-tree', title = 'Explorer', size = { height = 0.5 } },
      { ft = 'gitsigns-blame', title = 'Blame' },
      { ft = 'undotree', title = 'Undotree' },
    },
    bottom = {
      -- IntelliJ's Problems tool window.
      { ft = 'trouble', title = 'Problems', size = { height = 0.3 } },
    },
  },
}
