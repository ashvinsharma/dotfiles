-- [[ Copy keymaps: <leader>c* ]]
-- Various shortcuts for copying file paths / links to the system clipboard.

local permalink = require 'custom.settings.permalink'

vim.keymap.set('n', '<leader>cf', function() -- Get the current buffer's filename (tail only)
  local filename = vim.fn.expand '%:t'
  vim.fn.setreg('+', filename) -- Copy to system clipboard
  vim.notify('Copied filename: ' .. filename) -- Notify the user
end, { desc = '[C]opy [F]ilename' })

vim.keymap.set('n', '<leader>ca', function()
  local file_path = vim.fn.expand '%:p'
  vim.fn.setreg('+', file_path)
  vim.notify('Copied absolute path: ' .. file_path)
end, { desc = '[C]opy [A]bsolute file path' })

vim.keymap.set('n', '<leader>cr', function()
  -- 1. Get the Neo-tree state for the filesystem source
  local manager = require 'neo-tree.sources.manager'
  local state = manager.get_state 'filesystem'

  -- 2. Get the currently selected node in the tree
  local node = state.tree:get_node()

  if node then
    -- 3. Get the absolute path from the node
    local absolute_path = node.path

    -- 4. Convert to relative path based on the current working directory (cwd)
    local relative_path = vim.fn.fnamemodify(absolute_path, ':.')

    -- 5. Copy to clipboard and notify
    vim.fn.setreg('+', relative_path)
    vim.notify('Copied relative path: ' .. relative_path)
  else
    vim.notify('No file selected in Neo-tree', vim.log.levels.WARN)
  end
end, { desc = '[C]opy [R]elative path from Neo-tree' })

vim.keymap.set('n', '<leader>cp', function()
  if vim.bo.buftype ~= '' or vim.fn.expand '%:p' == '' then
    vim.notify('No file buffer to permalink', vim.log.levels.WARN)
    return
  end

  local file_path = vim.fn.expand '%:p'
  local file_dir = vim.fn.fnamemodify(file_path, ':h')

  local function git(args)
    local cmd = { 'git', '-C', file_dir }
    vim.list_extend(cmd, args)
    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
      return nil, vim.trim(output)
    end
    return vim.trim(output)
  end

  local sha, sha_err = git { 'rev-parse', 'HEAD' }
  if not sha then
    vim.notify('Not a git repository or no commits yet: ' .. (sha_err or ''), vim.log.levels.ERROR)
    return
  end

  -- Path of the file relative to the repo root, resolved by git itself so it
  -- is unaffected by symlinked worktree paths (e.g. /tmp -> /private/tmp on macOS).
  local prefix = git { 'rev-parse', '--show-prefix' } or ''
  local relative_path = prefix .. vim.fn.expand '%:t'

  local remotes_output = git { 'remote' }
  local remotes = remotes_output and vim.split(remotes_output, '\n', { trimempty = true }) or {}
  local remote_name = vim.tbl_contains(remotes, 'origin') and 'origin' or remotes[1]
  if not remote_name then
    vim.notify('No git remote configured for this repo', vim.log.levels.ERROR)
    return
  end

  local remote_url, remote_err = git { 'config', '--get', 'remote.' .. remote_name .. '.url' }
  if not remote_url or remote_url == '' then
    vim.notify('Could not read URL for remote "' .. remote_name .. '": ' .. (remote_err or ''), vim.log.levels.ERROR)
    return
  end

  local line = vim.fn.line '.'
  local url, err = permalink.build_url(remote_url, sha, relative_path, line)
  if not url then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  vim.fn.setreg('+', url)
  vim.notify('Copied permalink: ' .. url)
end, { desc = '[C]opy [P]ermalink (current commit)' })
