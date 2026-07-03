return {
  'ibhagwan/fzf-lua',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    -- Only used for <leader>sF (searching from an arbitrary root, e.g. home)
    -- -- Telescope's own EntryManager can take seconds to filter tens/
    -- hundreds of thousands of entries even with the native fzf sorter
    -- (its Lua-side entry wrapping/sorting dominates, not the matching
    -- itself -- see https://github.com/nvim-telescope/telescope.nvim/issues/2884).
    -- fzf-lua shells out to the real fzf binary instead of reimplementing
    -- that pipeline in Lua, so it stays instant at any scale.
    -- "telescope" profile keeps the look/feel consistent with the rest of
    -- the search keymaps, which stay on Telescope.
    require('fzf-lua').setup { 'telescope' }
  end,
}
