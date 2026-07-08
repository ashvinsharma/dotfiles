return {
  { 'tpope/vim-fugitive' },
  {
    -- Keys-only fragment: lazy.nvim merges this into the real
    -- 'nvim-neo-tree/neo-tree.nvim' spec (custom/plugins/neo-tree.lua) by
    -- plugin name. Kept here instead of there so every git-related keymap
    -- lives in one file -- this one just happens to be Neo-tree-backed.
    'nvim-neo-tree/neo-tree.nvim',
    keys = {
      { '<leader>tg', '<cmd>Neotree toggle git_status<CR>', desc = '[T]oggle [G]it status pane' },
    },
  },
  {
    'kdheepak/lazygit.nvim',
    cmd = 'LazyGit',
    keys = {
      { '<leader>gg', ':LazyGit<CR>', silent = true, noremap = true, desc = 'Open [G]it [G]ui (lazygit)' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
  },
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      -- Deep-extended onto gitsigns' own preview_config default (style =
      -- 'minimal', relative = 'cursor', ...), so this only adds a border
      -- without needing to repeat the rest. Covers both <leader>gB
      -- (blame_line) and <leader>gp (preview_hunk) since they share the
      -- same popup window config.
      preview_config = {
        border = 'rounded',
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous git [c]hange' })

        -- Actions
        -- visual mode
        map('v', '<leader>gs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [s]tage hunk' })
        map('v', '<leader>gr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [r]eset hunk' })
        -- normal mode
        map('n', '<leader>gs', gitsigns.stage_hunk, { desc = 'git [s]tage/unstage hunk' })
        map('n', '<leader>gr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
        map('n', '<leader>gS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
        map('n', '<leader>gR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
        map('n', '<leader>gp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
        map('n', '<leader>gb', gitsigns.blame, { desc = 'git [b]lame' })
        map('n', '<leader>gB', gitsigns.blame_line, { desc = 'git [B]lame line' })
        map('n', '<leader>gd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
        map('n', '<leader>gD', function()
          gitsigns.diffthis '@'
        end, { desc = 'git [D]iff against last commit' })
        -- Toggles
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
        map('n', '<leader>tD', gitsigns.preview_hunk_inline, { desc = '[T]oggle git show [D]eleted' })
      end,
    },
  },
}
