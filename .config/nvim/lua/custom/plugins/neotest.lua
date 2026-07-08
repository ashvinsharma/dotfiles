return { -- Test runner with gutter status + a results panel, like IntelliJ's test runner
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'nvim-neotest/nvim-nio',
    'nvim-neotest/neotest-go',
    -- Needs `rspec` in the project's Gemfile -- same mise-scoped-gem
    -- situation as ruby_lsp/rubocop/dap-ruby.
    'olimorris/neotest-rspec',
  },
  keys = function()
    -- neotest's summary/output-panel windows track "am I open" via their own
    -- saved window handle (neotest.lib.persistent_window). edgy.nvim docks
    -- them by *closing* the window neotest just created and opening its own
    -- in the right edge slot -- which silently invalidates that saved
    -- handle. neotest then thinks it's closed on the next toggle and opens
    -- ANOTHER one (which edgy docks too), leaving the previous one
    -- orphaned-but-still-visible: duplicate panels that accumulate on every
    -- toggle. Checking for a live window by filetype (ground truth) instead
    -- of trusting neotest's own tracking avoids this entirely.
    local function toggle_by_filetype(filetype, open_fn)
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == filetype then
          vim.api.nvim_win_close(win, false)
          return
        end
      end
      open_fn()
    end

    return {
      {
        '<leader>Tt',
        function()
          require('neotest').run.run()
        end,
        desc = '[T]est run nearest',
      },
      {
        '<leader>Tf',
        function()
          require('neotest').run.run(vim.fn.expand '%')
        end,
        desc = '[T]est run [F]ile',
      },
      {
        '<leader>Tl',
        function()
          require('neotest').run.run_last()
        end,
        desc = '[T]est run [L]ast',
      },
      {
        '<leader>TS',
        function()
          toggle_by_filetype('neotest-summary', require('neotest').summary.open)
        end,
        desc = '[T]est [S]ummary',
      },
      {
        '<leader>To',
        function()
          require('neotest').output.open { enter = true }
        end,
        desc = '[T]est [O]utput',
      },
      {
        '<leader>TO',
        function()
          toggle_by_filetype('neotest-output-panel', require('neotest').output_panel.open)
        end,
        desc = '[T]est [O]utput panel',
      },
      {
        '<leader>Tx',
        function()
          require('neotest').run.stop()
        end,
        desc = '[T]est stop',
      },
    }
  end,
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-go',
        require 'neotest-rspec',
      },
      -- Pass/fail icons next to the test line, not just in the summary panel.
      status = { virtual_text = true },
      output = { open_on_run = true },
      -- Default (0) auto-sizes the discovery worker pool to CPU count (18
      -- workers on this machine) -- each worker is a nested headless Neovim
      -- subprocess neotest spawns to offload treesitter parsing. The
      -- config's own doc comment says to set this to 1 "if experiencing
      -- lag"; left at 1 as a cheap precaution against spawning that many
      -- nested processes concurrently.
      discovery = { concurrent = 1 },
    }
  end,
}
