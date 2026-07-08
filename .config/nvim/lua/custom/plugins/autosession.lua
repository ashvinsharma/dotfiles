-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  'rmagatti/auto-session',
  lazy = false,
  enabled = true,
  keys = {
    -- <leader>S* = Session (capital, to avoid reading as "window" the way
    -- a lowercase <leader>w* would). Will use Telescope if installed or a
    -- vim.ui.select picker otherwise.
    { '<leader>Sf', '<cmd>AutoSession search<CR>', desc = '[S]ession [F]ind' },
    { '<leader>Ss', '<cmd>AutoSession save<CR>', desc = '[S]ession [S]ave' },
    { '<leader>Sa', '<cmd>AutoSession toggle<CR>', desc = '[S]ession toggle [A]utosave' },
  },
  ---enables autocomplete for opts
  ---@module "auto-session"
  ---@type AutoSession.Config
  opts = {
    suppressed_dirs = { '~/', '~/Projects', '~/Downloads', '/' },
    show_auto_restore_notif = true,
    load_on_setup = true,
    -- log_level = 'debug',
  },
}
