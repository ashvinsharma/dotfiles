return { -- Treesitter-based extract function/variable/block refactors.
  -- Distinct from inc-rename.nvim (nvim-lspconfig.lua's grn): that renames a
  -- symbol in place, this restructures code around a visual selection.
  'ThePrimeagen/refactoring.nvim',
  dependencies = {
    'lewis6991/async.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  keys = {
    {
      '<leader>r',
      function()
        require('refactoring').select_refactor { show_success_message = true }
      end,
      mode = 'v',
      desc = 'Refactor selection',
    },
  },
  opts = {},
}
