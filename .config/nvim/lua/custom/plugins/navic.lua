return { -- Winbar breadcrumbs (Class > method > if-block), like IntelliJ's top bar
  'SmiteshP/nvim-navic',
  -- Needs to register its LspAttach autocmd before any LSP client attaches
  -- to anything -- there's no ft/cmd/keys trigger that makes sense here
  -- (the <leader>tB keymap it defines is itself only created once this
  -- config runs, so it can't also be the thing that triggers loading).
  event = 'VeryLazy',
  config = function()
    local navic = require 'nvim-navic'
    navic.setup {
      highlight = true,
      separator = ' › ',
    }

    -- Only attach (and only show the winbar) for buffers whose LSP client
    -- actually supports documentSymbol -- otherwise every buffer gets an
    -- empty winbar wasting a line for nothing.
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('custom-navic', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or not client:supports_method 'textDocument/documentSymbol' then
          return
        end
        navic.attach(client, args.buf)
        vim.wo.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"
      end,
    })

    vim.keymap.set('n', '<leader>tB', function()
      if vim.wo.winbar == '' then
        vim.wo.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"
      else
        vim.wo.winbar = ''
      end
    end, { desc = '[T]oggle [B]readcrumbs' })
  end,
}
