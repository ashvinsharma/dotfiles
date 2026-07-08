return { -- Project-wide diagnostics list, like IntelliJ's Problems tool window
  'folke/trouble.nvim',
  cmd = 'Trouble',
  opts = {
    modes = {
      diagnostics = {
        -- Default aggregates diagnostics from every loaded buffer, which
        -- includes files opened incidentally via LSP navigation (e.g. "go
        -- to definition" into Go's standard library) -- not "my" code.
        -- Restrict to files under the current project.
        filter = {
          function(item)
            return item.filename:find((vim.uv or vim.loop).cwd(), 1, true) ~= nil
          end,
        },
      },
    },
  },
  keys = {
    { '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>', desc = '[X] Diagnostics (workspace)' },
    { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', desc = '[X] Diagnostics (buffer)' },
    { '<leader>xs', '<cmd>Trouble symbols toggle focus=false<CR>', desc = '[X] Symbols' },
    { '<leader>xl', '<cmd>Trouble lsp toggle focus=false win.position=right<CR>', desc = '[X] LSP references/definitions' },
    { '<leader>xL', '<cmd>Trouble loclist toggle<CR>', desc = '[X] Location list' },
    { '<leader>xQ', '<cmd>Trouble qflist toggle<CR>', desc = '[X] Quickfix list' },
  },
}
