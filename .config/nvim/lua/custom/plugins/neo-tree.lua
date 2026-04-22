-- This auto refreshes the tree whenever a file is changed
vim.api.nvim_create_autocmd({ 'BufLeave' }, {
  buffer = 0, -- or maybe vim.api.nvim_get_current_buf()
  callback = function()
    local events = require 'neo-tree.events'
    events.fire_event(events.GIT_EVENT)
  end,
})

return {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = true,
  keys = {
    { '<C-1>', '<cmd>Neotree toggle<CR>', desc = 'NeoTree toggle' },
    { '<C-0>', '<cmd>Neotree toggle git_status<CR>', desc = 'NeoTree toggle git changes pane' },
  },
  cmd = 'Neotree',
  ---@module "neo-tree"
  ---@type neotree.Config?
  opts = {
    clipboard = {
      sync = 'global',
    },
    close_if_last_window = true,
    -- This option is needed when the sessions are enabled. Check out https://github.com/nvim-neo-tree/neo-tree.nvim/pull/779
    auto_clean_after_session_restore = true,
    filesystem = {
      use_libuv_file_watcher = true,
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_ignored = false,
        hide_by_pattern = {
          '*/.DS_Store',
          '*/.git',
          '*/.idea',
        },
      },
      -- This will automatically open/select the file in the file explorer
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true, -- Close directories that aren't in the path of the current file
      },
    },
  },
}
