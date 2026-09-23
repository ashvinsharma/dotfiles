return { -- JetBrains-RubyMine-style REPL workflow: write Ruby in a real file
  -- (full LSP/autocomplete/diagnostics from nvim-lspconfig.lua), select or
  -- send it to a persistent `bin/rails console` process running in a
  -- vertical side split, and read its output there with normal
  -- terminal/tmux-style scrollback -- no leaving the editor.
  --
  -- Iron sends the raw text of whatever you send (line/paragraph/visual
  -- selection/file) as literal REPL input over the process's stdin -- it is
  -- NOT Ruby's `load`/`require`. That means re-sending the same
  -- line/selection after editing it just re-evaluates the new text in the
  -- console's current state; there's no `load 'file.rb'` indirection and no
  -- stale bytecode to worry about.
  --
  -- `event = 'VeryLazy'` is used instead of lazy-loading on `keys`: iron's
  -- own `keymaps` table (below) only creates the bindings once
  -- `require('iron.core').setup{}` has actually run, so the plugin needs to
  -- be loaded (and setup() called) up front rather than deferred until one
  -- of those keys is first pressed -- lazy.nvim's `keys`-triggered loading
  -- and iron's internal keymap registration are two different mechanisms
  -- and mixing them means the first keypress would do nothing.
  --
  -- iron's module path (`iron.core`) doesn't match the repo name
  -- (`iron.nvim`), so lazy.nvim's automatic `opts` -> `require(main).setup(opts)`
  -- inference won't find the right module. Calling setup() explicitly in
  -- `config` sidesteps that.
  'Vigemus/iron.nvim',
  event = 'VeryLazy',
  config = function()
    local iron = require 'iron.core'
    local view = require 'iron.view'

    iron.setup {
      config = {
        -- Override iron's built-in ruby repl_definition, which defaults to
        -- plain `irb` (see lua/iron/fts/ruby.lua upstream). The point of
        -- this whole setup is driving `bin/rails console`, not irb.
        --
        -- `bin/rails console` only resolves correctly when nvim's cwd is
        -- the Rails app root -- for this GDK, that's the `gitlab/`
        -- directory (e.g. ~/workspace/gitlab-org/gdk/gitlab). Open nvim
        -- from there, or `:cd` into it before toggling the repl. If you
        -- ever want a plain Ruby REPL alongside this, either add a second
        -- filetype-scoped repl_definition entry or temporarily change the
        -- `command` below back to { 'irb' }.
        repl_definition = {
          ruby = {
            command = { 'bin/rails', 'console' },
          },
        },

        -- Right-side vertical split sized to 40% of the editor width --
        -- closest analogue to a JetBrains console side panel.
        repl_open_cmd = view.split.vertical.botright '40%',

        -- Discard the repl buffer/process when closed rather than keeping
        -- it around as a hidden scratch buffer.
        scratch_repl = true,

        -- Pry/IRB (and by extension the rails console prompt built on
        -- them) can hiccup on blank lines inside a pasted multi-line
        -- block; skipping blank lines when sending a visual selection
        -- avoids that.
        --
        -- NOTE: the upstream README's own example puts `ignore_blank_lines`
        -- as a *sibling* of `config` (outside it), but that's misleading --
        -- verified against lua/iron/core.lua's setup(): it only ever reads
        -- opts.config (merging every key from it into the shared config
        -- table), opts.keymaps and opts.highlight. A top-level
        -- opts.ignore_blank_lines is never consulted, so following the
        -- README literally would silently no-op (invisible in the README's
        -- own example only because true already matches the built-in
        -- default in lua/iron/config.lua). Nesting it under `config`, as
        -- done here, is what the source actually checks.
        ignore_blank_lines = true,
      },

      -- NOTE: individual keymap values must be plain key-string, not a
      -- table with a `desc` field -- iron's core.setup passes the value
      -- straight through as the `lhs` argument to vim.keymap.set() and
      -- auto-generates its own desc ("iron_repl_<action>"); verified
      -- against the current upstream lua/iron/core.lua, there is no
      -- per-keymap options table in this schema.
      keymaps = {
        toggle_repl = '<leader>ii',
        restart_repl = '<leader>iR',
        send_file = '<leader>if',
        send_line = '<leader>il',
        visual_send = '<leader>iv',
        send_until_cursor = '<leader>iu',
        send_paragraph = '<leader>ip',
        exit = '<leader>iq',
        clear = '<leader>ic',
      },
    }

    -- :IronFocus / :IronHide are plain user commands (see :h iron-commands),
    -- separate from the named keymaps table above, so they're bound
    -- directly rather than through iron.setup{keymaps=...}.
    vim.keymap.set('n', '<leader>iF', '<cmd>IronFocus<cr>', { desc = 'Focus REPL window' })
    vim.keymap.set('n', '<leader>iH', '<cmd>IronHide<cr>', { desc = 'Hide REPL window' })
  end,
}
