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
      },
      commands = {
        all = {
          -- options for the message history that you get with `:Noice`
          view = 'split',
          opts = { enter = true, format = 'details' },
          filter = {},
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = true,
        lsp_doc_border = true,
      },
    }
  end,
}
