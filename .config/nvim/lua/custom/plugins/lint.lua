return {
  'mfussenegger/nvim-lint',
  event = { 'BufReadPre', 'BufNewFile' },
  config = function()
    local lint = require 'lint'
    -- golangci-lint reads whatever .golangci.yml/.yaml it finds upward from
    -- the file (or its own sane defaults if none exists) -- no per-project
    -- nvim config needed, it already adapts on its own. nvim-lint's bundled
    -- golangcilint linter is used as-is (plain PATH lookup); correct
    -- per-project version resolution comes from custom.settings.mise-env
    -- keeping $PATH in sync, not from anything here.
    lint.linters_by_ft = {
      sh = { 'shellcheck' },
      bash = { 'shellcheck' },
      zsh = { 'shellcheck' },
      go = { 'golangcilint' },
    }

    local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
      group = lint_augroup,
      callback = function()
        if vim.opt_local.modifiable:get() then
          -- nvim-lint has no notion of "the buffer's own directory" on its
          -- own -- linter jobs default to Neovim's global :pwd, which is
          -- wrong the moment you edit a file outside of it (e.g. opened via
          -- a cross-project search without :cd-ing first). golangci-lint
          -- specifically needs to run with cwd inside the actual module
          -- (it walks upward from cwd, not from the file path, to find
          -- go.mod/.golangci.yml) or it fails outright.
          lint.try_lint(nil, { cwd = vim.fn.expand '%:p:h' })
        end
      end,
    })
  end,
}
