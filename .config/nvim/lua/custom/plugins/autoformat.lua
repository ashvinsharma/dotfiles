return { -- Autoformat
  'stevearc/conform.nvim',
  enabled = true,
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>f',
      function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end,
      mode = '',
      desc = '[F]ormat buffer',
    },
  },
  opts = {
    notify_on_error = false,
    format_on_save = function(bufnr)
      -- Disable "format_on_save lsp_fallback" for languages that don't
      -- have a well standardized coding style. You can add additional
      -- languages here or re-enable it for the disabled ones.
      local disable_filetypes = { c = true, cpp = true }
      if disable_filetypes[vim.bo[bufnr].filetype] then
        return nil
      else
        -- golangci-lint fmt measured ~70-90ms standalone (cold cache
        -- included -- `fmt` only runs the lightweight gofmt/goimports
        -- formatters, not the full lint suite), but ~300ms under simulated
        -- CPU contention (8 concurrent invocations) -- already 60% of the
        -- default 500ms budget from contention alone, with no actual
        -- slowness in the tool. gopls/other saves competing for CPU on a
        -- real machine can plausibly push it over 500ms and silently drop
        -- the format. Other formatters here (stylua, shfmt, ...) are
        -- simple text formatters with no reason to be anywhere near that
        -- slow, so they keep the tighter default.
        local timeout_ms = vim.bo[bufnr].filetype == 'go' and 2000 or 500
        return {
          timeout_ms = timeout_ms,
          lsp_format = 'fallback',
        }
      end
    end,
    formatters_by_ft = {
      lua = { 'stylua' },
      go = { 'golangci_lint_fmt' },
      sh = { 'shfmt' },
      bash = { 'shfmt' },
      zsh = { 'shfmt' },
      yaml = { 'yamlfmt' },
      terraform = { 'tofu_fmt' },
    },
    -- Custom formatters not built into conform
    formatters = {
      -- OpenTofu uses `tofu fmt` instead of `terraform fmt`.
      -- The `-` flag makes it read from stdin, which is how conform pipes files through.
      tofu_fmt = {
        command = 'tofu',
        args = { 'fmt', '-' },
        stdin = true,
      },
      -- `golangci-lint fmt` applies whatever formatters.* section a
      -- project's own .golangci.yml declares (custom gofmt rewrite rules,
      -- goimports local-prefixes, etc.), falling back to plain gofmt +
      -- goimports if the project has no such config -- adapts per project
      -- automatically, no per-project nvim file needed. Plain PATH lookup;
      -- correct per-project version resolution comes from
      -- custom.settings.mise-env keeping $PATH in sync, not from anything
      -- here. cwd is rooted at the nearest .golangci.yml/go.mod so
      -- golangci-lint's own config discovery looks in the right place
      -- regardless of Neovim's global cwd.
      golangci_lint_fmt = {
        command = 'golangci-lint',
        args = { 'fmt', '--stdin' },
        stdin = true,
        -- Deferred: calling require('conform.util') here (rather than at
        -- the top of this file) avoids requiring conform's own runtime
        -- files before lazy.nvim has necessarily loaded them -- this table
        -- is evaluated when lazy.nvim parses the spec, which can happen
        -- before conform.nvim itself is on the runtimepath.
        cwd = function(self, ctx)
          return require('conform.util').root_file { '.golangci.yml', '.golangci.yaml', 'go.mod', 'go.work' }(self, ctx)
        end,
      },
    },
  },
}
