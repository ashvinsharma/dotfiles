return { -- In-editor HTTP client: write requests in .http files, run them,
  -- see the response without leaving nvim.
  --
  -- Pinned to v1.2.1, the last release before rest.nvim's v2 rewrite, which
  -- moved its curl/mimetype/XML deps to luarocks rockspec dependencies
  -- (needs a working Lua 5.1 + luarocks toolchain to build). v1.2.1 is
  -- plenary+curl only, no build step, and its config API is what's used
  -- below (result.formatters, skip_ssl_verification, etc.).
  'rest-nvim/rest.nvim',
  tag = 'v1.2.1',
  ft = 'http',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    { '<leader>rr', '<Plug>RestNvim', desc = 'Run request under cursor', ft = 'http' },
    { '<leader>rl', '<Plug>RestNvimLast', desc = 'Re-run last request', ft = 'http' },
  },
  -- lazy.nvim infers the main module from the plugin/repo name (rest.nvim),
  -- but v1.2.1's module is require('rest-nvim') (hyphenated) -- an explicit
  -- config() is needed since `opts` alone can't find it to call .setup().
  config = function()
    require('rest-nvim').setup {
      result = {
        formatters = {
          json = 'jq',
        },
      },
    }
  end,
}
