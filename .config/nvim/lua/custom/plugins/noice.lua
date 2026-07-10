return {
  -- messages, cmdline and the popupmenu
  'folke/noice.nvim',
  event = 'VeryLazy',
  dependencies = {
    'MunifTanjim/nui.nvim',
    'rcarriga/nvim-notify',
  },
  opts = function()
    local focused = true
    vim.api.nvim_create_autocmd('FocusGained', {
      callback = function()
        focused = true
      end,
    })
    vim.api.nvim_create_autocmd('FocusLost', {
      callback = function()
        focused = false
      end,
    })

    -- The shell_out/shell_err route's split accumulates forever: Neovim
    -- gives each new :!/:grep invocation its own distinct message (with
    -- replace_last=false), and noice's router always view:push()es routed
    -- messages (message/router.lua) -- there's no "replace the last one"
    -- concept for split-backed routes, only for notify (which has its own
    -- separate `replace`-by-id mechanism that doesn't apply here). Clearing
    -- right before a new :!/:grep runs (not after -- the message itself
    -- only arrives once the external command finishes) means the split is
    -- empty when the fresh output lands, instead of stacking under the
    -- previous run's. `:Noice dismiss` clears every active noice view, not
    -- just this one, but everything else noice shows is already
    -- transient/self-clearing, so that's not a real loss.
    vim.api.nvim_create_autocmd('CmdlineLeave', {
      pattern = ':',
      callback = function()
        local cmdline = vim.fn.getcmdline()
        if cmdline:match '^!' or cmdline:match '^grep' or cmdline:match '^lgrep' then
          vim.cmd 'Noice dismiss'
        end
      end,
    })

    return {
      lsp = {
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
          ['cmp.entry.get_documentation'] = true,
        },
      },
      routes = {
        {
          filter = {
            cond = function()
              return not focused
            end,
          },
          view = 'notify_send',
          opts = { stop = false },
        },
        {
          filter = {
            event = 'notify',
            find = 'No information available',
          },
          opts = { skip = true },
        },
        {
          -- https://github.com/folke/noice.nvim/issues/1097 -- shell_out/
          -- shell_err messages have no `level` set, which noice otherwise
          -- silently drops entirely. Setting level here is what actually
          -- keeps them from vanishing; split (rather than notify) as the
          -- view since this also covers :grep's own shelled-out output,
          -- which can be many lines long -- better suited to a scrollable
          -- split than a small popup.
          filter = { event = 'msg_show', kind = { 'shell_out', 'shell_err' } },
          view = 'split',
          opts = {
            level = 'info',
            skip = false,
            replace = false,
            -- The "split" view's own default (noice/config/views.lua) is
            -- enter=false. nui.split:mount() reads this directly
            -- (nui/split/init.lua) and calls nvim_set_current_win() when
            -- true -- confirmed in nui.nvim's source, this is a real,
            -- respected option, not a no-op.
            enter = true,
          },
        },
      },
      -- commands = {
      --   all = {
      --     -- options for the message history that you get with `:Noice`
      --     view = 'split',
      --     opts = { enter = true, format = 'details' },
      --     filter = {},
      --   },
      -- },
      presets = {
        bottom_search = true,
        command_palette = false,
        long_message_to_split = true,
        inc_rename = true,
        lsp_doc_border = true,
      },
    }
  end,
}
