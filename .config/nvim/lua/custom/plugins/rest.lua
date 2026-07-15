return { -- In-editor HTTP client: write requests in .http files, run them,
  -- see the response without leaving nvim.
  --
  -- v3.x's rockspec deps (tree-sitter-http, mimetypes, xml2lua) need
  -- luarocks to see a Lua 5.1-compatible interpreter to build/install
  -- against -- `brew install luajit` covers that (LuaJIT reports itself as
  -- Lua 5.1). None of those deps actually link against liblua though
  -- (mimetypes/xml2lua are pure Lua, tree-sitter-http is a treesitter
  -- grammar loaded via dlopen, same as any other parser), so this is
  -- luarocks' own version-gate metadata check, not a real ABI requirement.
  --
  -- v3 dropped the v1.2.1 API entirely: no more `<Plug>RestNvim*` mappings
  -- (replaced by `:Rest run`/`:Rest last` commands) and no more
  -- `require('rest-nvim').setup{}` (config is `vim.g.rest_nvim` now, and
  -- its schema has no per-content-type formatters table -- JSON pretty-
  -- printing goes through `response.hooks.format` (native `gq`) instead of
  -- the old explicit `result.formatters.json = 'jq'`).
  'rest-nvim/rest.nvim',
  tag = 'v3.13.0',
  ft = 'http',
  -- `http` parser is installed via treesitter.lua's own language list, not
  -- through the legacy nvim-treesitter.configs `ensure_installed` merge
  -- pattern rest.nvim's README assumes (main branch's minimal API doesn't
  -- have that mechanism).
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    { '<leader>rr', '<cmd>Rest run<CR>', desc = 'Run request under cursor', ft = 'http' },
    { '<leader>rl', '<cmd>Rest last<CR>', desc = 'Re-run last request', ft = 'http' },
  },
}
