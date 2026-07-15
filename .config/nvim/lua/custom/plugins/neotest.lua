-- `-race` roughly triples per-run wall time (recompiles with instrumentation
-- on every invocation) -- fine for CI/full-suite runs, too slow for
-- iterate-on-one-test-in-the-editor. go_test_args as a function (rather than
-- a static table) gets re-evaluated on every run regardless of how it's
-- triggered -- keymap, `:Neotest`, or the summary window's own run mapping --
-- so toggling this one variable is enough, no config edits/restarts needed.
local race_enabled = false

return { -- Test runner with gutter status + a results panel, like IntelliJ's test runner
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'nvim-neotest/nvim-nio',
    {
      'fredrikaverpil/neotest-golang',
      version = '*',
      -- `gotestsum` is already on PATH via mise (see debug.lua's mise-scoped
      -- tooling comments) -- no build step needed to fetch it.
    },
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

    local neotest = require 'neotest'

    return {
      {
        '<leader>Tt',
        function()
          neotest.run.run()
        end,
        desc = '[T]est run nearest',
      },
      {
        '<leader>Tf',
        function()
          neotest.run.run(vim.fn.expand '%')
        end,
        desc = '[T]est run [F]ile',
      },
      {
        '<leader>Tl',
        function()
          neotest.run.run_last()
        end,
        desc = '[T]est run [L]ast',
      },
      {
        '<leader>TS',
        function()
          toggle_by_filetype('neotest-summary', neotest.summary.open)
        end,
        desc = '[T]est [S]ummary',
      },
      {
        '<leader>To',
        function()
          neotest.output_panel.toggle()
        end,
        desc = '[T]est [O]utput',
      },
      {
        '<leader>TO',
        function()
          toggle_by_filetype('neotest-output-panel', neotest.output.open { enter = true })
        end,
        desc = '[T]est [O]utput panel',
      },
      {
        '<leader>Tx',
        function()
          neotest.run.stop()
        end,
        desc = '[T]est stop',
      },
      {
        '<leader>TR',
        function()
          race_enabled = not race_enabled
          vim.notify('neotest: -race ' .. (race_enabled and 'enabled' or 'disabled'), vim.log.levels.INFO)
        end,
        desc = '[T]est [R]ace toggle',
      },
    }
  end,
  config = function()
    local neotest = require 'neotest'

    neotest.setup {
      adapters = {
        -- Replaces neotest-go: that adapter never passed a `-run` flag to
        -- `go test` at all (confirmed by reading its source -- no `-run`
        -- anywhere), so every run -- nearest test, file, whatever --
        -- silently executed the entire package and matched results back to
        -- the selected position client-side. neotest-golang does real
        -- per-position `-run` scoping via treesitter AST parsing.
        require 'neotest-golang' {
          runner = 'gotestsum',
          go_test_args = function()
            local args = { '-v', '-count=1' }
            if race_enabled then
              table.insert(args, '-race')
            end
            return args
          end,
        },
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
      consumers = {
        -- The client emits a "run" event on client/state whenever any run
        -- is kicked off, no matter the entry point (keymap, `:Neotest`
        -- command, or the summary window's own run mapping) -- so hooking
        -- it here clears+reopens the output panel universally, instead of
        -- patching every place a run can be triggered from.
        reset_output_panel_on_run = function(client)
          client.listeners.run = function()
            neotest.output_panel.clear()
            neotest.output_panel.open()
          end
          return {}
        end,
      },
    }

    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'neotest-output-panel',
      callback = function(args)
        vim.keymap.set('n', '<leader>Toc', function()
          require('neotest').output_panel.clear()
        end, { buffer = args.buf, desc = '[T]est [O]utput [C]lear' })
      end,
    })
  end,
}
