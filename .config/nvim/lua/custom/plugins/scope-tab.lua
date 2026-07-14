return {
  'tiagovla/scope.nvim',
  config = function()
    require('scope').setup {}

    -- Plain `:bd`/`:bdelete` can close the whole tab instead of just the
    -- buffer: if the buffer (or any other listed buffer) is already open in
    -- another tab, Neovim jumps there and closes the current window rather
    -- than leaving an empty scratch buffer (this is core Neovim behavior,
    -- not something scope.nvim causes). Route the bare command through
    -- scope's tab-aware close instead, which only closes the tab when that's
    -- actually the last buffer scoped to it.
    vim.cmd [[
      cnoreabbrev <expr> bd getcmdtype() == ':' && getcmdline() ==# 'bd' ? 'lua require("scope.core").close_buffer({ ask = true })' : 'bd'
      cnoreabbrev <expr> bdelete getcmdtype() == ':' && getcmdline() ==# 'bdelete' ? 'lua require("scope.core").close_buffer({ ask = true })' : 'bdelete'
    ]]
  end,
}
