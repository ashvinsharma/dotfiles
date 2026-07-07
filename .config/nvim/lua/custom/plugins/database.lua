return {
  'tpope/vim-dadbod',
  dependencies = {
    'kristijanhusak/vim-dadbod-ui',
    'kristijanhusak/vim-dadbod-completion',
  },
  cmd = {
    'DB',
    'DBUI',
    'DBUIToggle',
    'DBUIAddConnection',
    'DBUIFindBuffer',
  },
  init = function()
    vim.g.db_ui_use_nerd_fonts = vim.g.have_nerd_font
    vim.g.db_ui_save_location = vim.fn.stdpath 'data' .. '/db_ui_queries'

    -- Connection list lives outside the (versioned) dotfiles repo, since URLs
    -- can carry credentials. See ~/.local/share/nvim/db_connections.lua.
    local connections_file = vim.fn.stdpath 'data' .. '/db_connections.lua'
    if vim.fn.filereadable(connections_file) == 1 then
      vim.g.dbs = dofile(connections_file)
    end

    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'sql', 'mysql', 'plsql' },
      callback = function()
        require('cmp').setup.buffer {
          sources = {
            { name = 'vim-dadbod-completion' },
            { name = 'luasnip' },
            { name = 'path' },
          },
        }
      end,
    })

    vim.keymap.set('n', '<leader>du', '<cmd>DBUIToggle<CR>', { desc = '[D]atabase [U]I toggle' })
    vim.keymap.set('n', '<leader>df', '<cmd>DBUIFindBuffer<CR>', { desc = '[D]atabase [F]ind buffer' })
    vim.keymap.set('n', '<leader>da', '<cmd>DBUIAddConnection<CR>', { desc = '[D]atabase [A]dd connection' })
  end,
}
