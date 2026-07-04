-- Neovim's own $PATH/env vars are fixed at process launch. mise resolves
-- per-directory tool versions (go, golangci-lint, gopls itself, etc.), but
-- that only reaches Neovim if something re-syncs the environment as you
-- move between projects -- otherwise gopls, :terminal, and any tool
-- invoked from inside Neovim keeps using whatever was resolved for the
-- directory Neovim happened to start in, even after opening a file that
-- belongs to a different project.
--
-- Runs on BufReadPre/BufNewFile (not just DirChanged/:cd) specifically so
-- it also covers opening a file from another project directly without
-- explicitly `:cd`-ing into it first (e.g. via a cross-project search) --
-- mise.nvim's own :cd-only trigger doesn't cover that case.
--
-- This only needs to run once per distinct project root: an already-
-- spawned LSP client (or any already-running process) keeps whatever env
-- it inherited at spawn time regardless of later changes here, so this
-- only has to be correct *before* a new client/job for that root is first
-- started, not continuously.
if vim.fn.executable 'mise' == 0 then
  return
end

local last_root = nil

local function sync(dir)
  local root = vim.fs.root(dir, { '.mise.toml', 'mise.toml', '.tool-versions' })
  if not root or root == last_root then
    return
  end
  last_root = root

  local result = vim.system({ 'mise', 'env', '-s', 'bash' }, { cwd = root, text = true }):wait()
  if result.code ~= 0 then
    return
  end

  for line in result.stdout:gmatch '[^\r\n]+' do
    local key, value = line:match "^export ([%w_]+)=(.*)$"
    if key then
      value = value:gsub("^['\"]", ''):gsub("['\"]$", '')
      vim.env[key] = value
    end
  end
end

vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
  group = vim.api.nvim_create_augroup('mise_env_sync', { clear = true }),
  callback = function(args)
    local dir = vim.fn.fnamemodify(args.file, ':p:h')
    if vim.uv.fs_stat(dir) then
      sync(dir)
    end
  end,
})
