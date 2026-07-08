-- [[ Graphviz preview, wired into <leader>tp (see custom/plugins/preview.lua) ]]
-- Renders live buffer content (not the file on disk, so unsaved edits show
-- up) via stdin, so no scratch source file is needed -- only the rendered
-- SVG lands in /tmp, timestamped so repeated previews never clobber each
-- other or overwrite a previous render you still have open.
--
-- Registered into the shared `previewers` table instead of its own
-- dedicated keymap, so `.dot`/`.fabro` buffers preview through the same
-- <leader>tp binding as markdown. This file loads directly from init.lua,
-- earlier than preview.lua (loaded later via lazy.nvim), hence `or {}`.
_G.previewers = _G.previewers or {}
_G.previewers.dot = function()
  if vim.fn.executable 'dot' == 0 then
    vim.notify('Graphviz `dot` not found on PATH', vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t:r')
  if name == '' then
    name = 'graph'
  end
  local out = string.format('/tmp/%s-%s.svg', name, os.date '%Y%m%d-%H%M%S')

  local source = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  vim.fn.system({ 'dot', '-Tsvg', '-o', out }, source)
  if vim.v.shell_error ~= 0 then
    vim.notify('dot render failed (exit ' .. vim.v.shell_error .. ')', vim.log.levels.ERROR)
    return
  end

  vim.fn.jobstart({ 'open', out }, { detach = true })
  vim.notify('Rendered ' .. out)
end
