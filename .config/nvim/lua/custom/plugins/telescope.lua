-- This disables codefold when preview under telescope results
-- This is needed when using grep across the project files
vim.api.nvim_create_autocmd('FileType', { pattern = 'TelescopeResults', command = [[setlocal nofoldenable]] })

return { -- Fuzzy Finder (files, lsp, etc)
  'nvim-telescope/telescope.nvim',
  event = 'VimEnter',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { -- If encountering errors, see telescope-fzf-native README for installation instructions
      'nvim-telescope/telescope-fzf-native.nvim',

      -- `build` is used to run some command when the plugin is installed/updated.
      -- This is only run then, not every time Neovim starts up.
      build = 'make',

      -- `cond` is a condition used to determine whether this plugin should be
      -- installed and loaded.
      cond = function()
        return vim.fn.executable 'make' == 1
      end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },

    -- Undo history browser: left column of numbered undo states, right
    -- pane a delta-rendered (syntax highlighted, colored) diff preview --
    -- replaces mbbill/undotree, which only supports fixed splits, not this
    -- kind of list+preview layout.
    { 'debugloop/telescope-undo.nvim' },

    -- Popup file browser (create/rename/move/delete) rooted at the current
    -- buffer's directory -- lighter-weight than opening the persistent
    -- Neo-tree sidebar (<leader>e) for one-off file operations.
    { 'nvim-telescope/telescope-file-browser.nvim' },

    -- Useful for getting pretty icons, but requires a Nerd Font.
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    -- Telescope is a fuzzy finder that comes with a lot of different things that
    -- it can fuzzy find! It's more than just a "file finder", it can search
    -- many different aspects of Neovim, your workspace, LSP, and more!
    --
    -- The easiest way to use Telescope, is to start by doing something like:
    --  :Telescope help_tags
    --
    -- After running this command, a window will open up and you're able to
    -- type in the prompt window. You'll see a list of `help_tags` options and
    -- a corresponding preview of the help.
    --
    -- Two important keymaps to use while in Telescope are:
    --  - Insert mode: <c-/>
    --  - Normal mode: ?
    --
    -- This opens a window that shows you all of the keymaps for the current
    -- Telescope picker. This is really useful to discover what Telescope can
    -- do as well as how to actually do it!

    -- Outside a git repo (e.g. searching from home or a parent directory),
    -- fd/rg have no .gitignore to prune with and will otherwise fully crawl
    -- node_modules, ~/Library, ~/.cache, etc. file_ignore_patterns (below)
    -- only filters results *after* the whole tree is already walked -- it
    -- doesn't stop fd/rg from descending into these directories, which is
    -- the actual cost. --exclude/--glob tell them to skip descending
    -- entirely, which is what actually keeps this fast.
    local prune_dirs = {
      'node_modules',
      '.git',
      'dist',
      'build',
      'target',
      'vendor',
      '.cache',
      'Library',
      '.npm',
      '.cargo',
      '.rustup',
      '.nvm',
      '.rbenv',
      '.Trash',
      '.docker',
      -- Measured on this machine: .local (~1.15M files, nvim/mason/pip/npm
      -- caches under ~/.local/share) and go (~590K, ~/go/pkg/mod module
      -- cache) alone accounted for ~91% of a 1.9M-file home directory scan.
      -- Neither is something you'd fuzzy-search by hand.
      '.local',
      'go',
      'Applications',
      -- Second pass, measured after the above: still 145K files at ~/,
      -- with the native sorter taking several seconds per keystroke to
      -- rescore all of them. These are all tool caches/state directories,
      -- not source you'd fuzzy-search -- pruning them roughly halves the
      -- remaining count.
      'Arc_backup',
      '.bun',
      '.claude',
      '.glci',
      '.bundle',
      '.ollama',
      '.windsurf',
      '.serena',
      '.kube',
      '.yarn',
      '.oh-my-zsh',
      '.berkshelf',
      '.vscode',
      '.gkg',
      '.codeium',
      '.luarocks',
      '.cursor',
      '.gem',
      '.swiftpm',
      'PyCharmMiscProject',
    }
    local fd_exclude_args = {}
    local rg_glob_args = {}
    for _, dir in ipairs(prune_dirs) do
      vim.list_extend(fd_exclude_args, { '--exclude', dir })
      vim.list_extend(rg_glob_args, { '--glob', '!' .. dir })
    end

    -- [[ Configure Telescope ]]
    -- See `:help telescope` and `:help telescope.setup()`
    require('telescope').setup {
      -- You can put your default mappings / updates / etc. in here
      --  All the info you're looking for is in `:help telescope.setup()`
      --
      -- defaults = {
      --   mappings = {
      --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
      --   },
      -- },
      defaults = {
        vimgrep_arguments = vim.list_extend(
          { 'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case' },
          rg_glob_args
        ),
        -- Kept as a fallback for any picker that doesn't go through
        -- find_command/vimgrep_arguments (e.g. buffer/help pickers never
        -- hit this, but it's harmless there).
        file_ignore_patterns = { 'node_modules/', '%.git/', 'dist/', 'build/', 'target/', 'vendor/', '%.cache/' },
      },
      pickers = {
        find_files = {
          find_command = vim.list_extend({ 'fd', '--type', 'f', '--hidden', '--follow', '--color', 'never' }, fd_exclude_args),
        },
        colorscheme = { enable_preview = true },
      },
      extensions = {
        ['ui-select'] = {
          require('telescope.themes').get_dropdown(),
        },
        undo = {
          -- use_delta only exposes a toggle for side-by-side (-s); to add
          -- --line-numbers this has to fully replace the delta invocation
          -- via use_custom_command instead (this is the exact same
          -- built-in bash pipeline, plus that one flag).
          use_custom_command = { 'bash', '-c', "echo '$DIFF' | delta --line-numbers" },
          -- telescope-undo.nvim hardcodes prompt_title = "Undo History" as
          -- a *default*, which pickers.new(opts, defaults) only applies
          -- when opts doesn't already set that key -- so setting it here
          -- overrides it, putting the keybind reminder directly in
          -- Telescope's own UI chrome instead of a separate popup.
          prompt_title = 'Undo History  (u restore · y/Y yank +/-)',
        },
        file_browser = {
          -- Root the browser at the current buffer's directory rather than cwd.
          path = '%:p:h',
          hijack_netrw = true,
          hidden = true,
          respect_gitignore = false,
        },
      },
    }

    -- Enable Telescope extensions if they are installed
    pcall(require('telescope').load_extension, 'fzf')
    pcall(require('telescope').load_extension, 'ui-select')
    pcall(require('telescope').load_extension, 'undo')
    pcall(require('telescope').load_extension, 'file_browser')

    -- See `:help telescope.builtin`
    local builtin = require 'telescope.builtin'
    local buffers_sorted_by_recency = function()
      builtin.buffers { sort_mru = true, ignore_current_buffer = true }
    end

    -- sf/sw/sg move to fzf-lua below: all three scale with project/content
    -- size (file listing, word grep, full-text grep), where Telescope's
    -- EntryManager overhead is most noticeable. Everything else here stays
    -- bounded/small, where Telescope's overhead doesn't matter.
    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader>sf', function()
      require('fzf-lua').files { hidden = true }
    end, { desc = '[S]earch [F]iles (fzf-lua)' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set('n', '<leader>sw', function()
      require('fzf-lua').grep_cword()
    end, { desc = '[S]earch current [W]ord (fzf-lua)' })
    vim.keymap.set('n', '<leader>sg', function()
      require('fzf-lua').live_grep()
    end, { desc = '[S]earch by [G]rep (fzf-lua)' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader><leader>', buffers_sorted_by_recency, { desc = '[ ] Find existing buffers' })
    vim.keymap.set('n', '<leader>su', function()
      require('telescope').extensions.undo.undo()
    end, { desc = '[S]earch [U]ndo history' })
    vim.keymap.set('n', '<leader>sb', function()
      require('telescope').extensions.file_browser.file_browser()
    end, { desc = '[S]earch file [B]rowser' })

    -- Slightly advanced example of overriding default behavior and theme
    vim.keymap.set('n', '<leader>/', function()
      -- You can pass additional configuration to Telescope to change the theme, layout, etc.
      builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        winblend = 10,
        previewer = false,
      })
    end, { desc = '[/] Fuzzily search in current buffer' })

    -- It's also possible to pass additional configuration options.
    --  See `:help telescope.builtin.live_grep()` for information about particular keys
    vim.keymap.set('n', '<leader>s/', function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end, { desc = '[S]earch [/] in Open Files' })

    -- Shortcut for searching your Neovim configuration files
    vim.keymap.set('n', '<leader>sn', function()
      builtin.find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[S]earch [N]eovim files' })

    -- find_files/live_grep are always rooted at cwd -- fd/rg already do
    -- fast recursive search at any depth, they just need to be pointed
    -- somewhere other than cwd (e.g. a parent directory). Prompt for a root
    -- (defaulting to cwd's parent) and search fully recursively from there.
    local function prompt_root(default)
      local resolved = vim.fn.fnamemodify(default, ':p')
      return vim.fn.input('Search from: ', resolved, 'dir')
    end

    -- Uses fzf-lua, not Telescope -- Telescope's own EntryManager takes
    -- seconds to filter tens/hundreds of thousands of entries at arbitrary
    -- roots like home (the matching itself is fast, its Lua-side entry
    -- wrapping/sorting isn't). fzf-lua shells out to the real fzf binary
    -- and stays instant at any scale. See lua/custom/plugins/fzf-lua.lua.
    vim.keymap.set('n', '<leader>sF', function()
      local root = prompt_root '..'
      if root == '' then
        return
      end
      require('fzf-lua').files { cwd = root, hidden = true }
    end, { desc = '[S]earch [F]iles from directory (fzf-lua)' })

    vim.keymap.set('n', '<leader>sG', function()
      local root = prompt_root '..'
      if root == '' then
        return
      end
      require('fzf-lua').live_grep { cwd = root }
    end, { desc = '[S]earch [G]rep from directory (fzf-lua)' })
  end,
}
