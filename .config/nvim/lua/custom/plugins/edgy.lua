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
      -- Explicit heights on every view here (not just Explorer): views
      -- sharing an edgy column all get re-laid-out together whenever any
      -- sibling's visibility changes, so an unsized view's share of the
      -- column would silently shift (and visibly resize on screen) every
      -- time Explorer toggled. Fixed ratios keep each view's size stable
      -- regardless of which siblings are currently open.
      { ft = 'neo-tree', title = 'Explorer', size = { height = 0.4 } },
      { ft = 'gitsigns-blame', title = 'Blame', size = { height = 0.2 } },
      { ft = 'undotree', title = 'Undotree', size = { height = 0.2 } },
      -- Test results tree, like IntelliJ's test runner panel.
      { ft = 'neotest-summary', title = 'Tests', size = { height = 0.2 } },
    },
    bottom = {
      -- IntelliJ's Problems tool window.
      { ft = 'trouble', title = 'Problems', size = { height = 0.3 } },
      -- Test output console, like IntelliJ's test runner console.
      { ft = 'neotest-output-panel', title = 'Test Output', size = { height = 0.3 } },
    },
  },
}
