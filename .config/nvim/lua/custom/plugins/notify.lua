return {
  'rcarriga/nvim-notify',
  init = function()
    -- Lazily require so this works even for notifications fired before the
    -- plugin object has fully loaded/applied opts.
    --
    -- Drops exactly one specific message: Neovim core's vim/_watch.lua hits
    -- this every session an LSP server (gopls) registers a workspace watch
    -- on a directory that doesn't exist (e.g. an unvendored vendor/ dir) --
    -- see https://github.com/neovim/neovim/issues/28058. Neovim's own
    -- source comment calls it "a placeholder until we have `nvim_log` API",
    -- and it's deduped to fire at most once per session anyway
    -- (vim.notify_once), so silencing this one exact message doesn't risk
    -- hiding a real, different problem -- everything else still comes
    -- through normally.
    vim.notify = function(msg, ...)
      if type(msg) == 'string' and msg:match '^watch%.watch: ENOENT' then
        return
      end
      return require('notify')(msg, ...)
    end

    -- Bridge LSP $/progress events (workspace loading, indexing, etc.) into
    -- the same notify system instead of fidget.nvim's separate progress
    -- window in its own corner. Neovim exposes this natively via the
    -- LspProgress autocmd (since 0.10) -- fidget was only ever a thin
    -- renderer on top of the exact same event.
    --
    -- One notification per (client, token), updated in place via notify's
    -- `replace` option as begin/report/end messages arrive, instead of
    -- spawning a new one for every percentage tick.
    local lsp_progress_notifs = {} ---@type table<string, integer>
    vim.api.nvim_create_autocmd('LspProgress', {
      callback = function(args)
        local value = args.data.params.value
        if type(value) ~= 'table' then
          return
        end

        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local key = args.data.client_id .. ':' .. tostring(args.data.params.token)

        local msg = value.title or ''
        if value.message and value.message ~= '' then
          msg = msg ~= '' and (msg .. ': ' .. value.message) or value.message
        end
        if value.percentage then
          msg = msg .. string.format(' (%d%%)', value.percentage)
        end
        if msg == '' then
          msg = value.kind
        end

        local notif = vim.notify(msg, vim.log.levels.INFO, {
          title = client and client.name or 'LSP',
          replace = lsp_progress_notifs[key],
          timeout = value.kind == 'end' and 1500 or false,
          hide_from_history = true,
        })
        if value.kind == 'end' then
          lsp_progress_notifs[key] = nil
        elseif notif then
          lsp_progress_notifs[key] = notif.id
        end
      end,
    })
  end,
  opts = function()
    local colors = require 'custom.colors'
    return {
      -- Explicit background: Normal is transparent (see nightfox.lua), and
      -- notify windows blend against 'Normal' by default, which would
      -- otherwise show through to the terminal background inconsistently.
      background_colour = colors.surface0,
      timeout = 3000,
      top_down = true,
      stages = 'fade_in_slide_out',
      render = 'compact',
      max_width = 80,
    }
  end,
}
