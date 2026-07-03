-- Live, verbose expansion of what custom/plugins/mini-vim.lua's statusline
-- shows -- the same values, spelled out in full instead of a truncated
-- icon/count, plus the things it can't fit at all (LSP client names, actual
-- diagnostic messages, full file path). Regenerated fresh on every toggle
-- and kept live while open. Toggle with <leader>ts.

local M = {}

local win_id = nil
local buf_id = nil
-- The buffer/window the report is *about* -- captured once when the popup
-- opens, since by the time anything inside it runs, the popup itself is
-- the current buffer/window.
local target_bufnr = nil
local target_winid = nil
local augroup = vim.api.nvim_create_augroup('StatuslineReport', { clear = true })

local function bytes_to_human(n)
  if n < 1024 then
    return n .. 'B'
  elseif n < 1024 * 1024 then
    return string.format('%.1fK', n / 1024)
  else
    return string.format('%.1fM', n / (1024 * 1024))
  end
end

local mode_names = {
  n = 'Normal',
  no = 'Normal (pending operator)',
  i = 'Insert',
  v = 'Visual',
  V = 'Visual Line',
  ['\22'] = 'Visual Block',
  s = 'Select',
  S = 'Select Line',
  ['\19'] = 'Select Block',
  R = 'Replace',
  Rv = 'Virtual Replace',
  c = 'Command-line',
  t = 'Terminal',
}

---Report data is about the buffer/window that was current *before* the
---popup opened, captured once in open() -- everything below must take it
---explicitly rather than asking for "the current buffer", since by the
---time this runs the popup itself is current.
---@param bufnr integer
---@param winid integer
---@return string[] lines
---@return {line: integer, col_end: integer}[] label_spans -- ranges to dim as labels
local function build_lines(bufnr, winid)
  local cursor = vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_cursor(winid) or { 0, 0 }
  local lines = {}
  local label_spans = {}

  local function add(label, value)
    if label == nil then
      table.insert(lines, '')
      return
    end
    table.insert(lines, ('%s: %s'):format(label, value))
    table.insert(label_spans, { line = #lines - 1, col_end = #label + 1 })
  end

  add('Mode', mode_names[vim.api.nvim_get_mode().mode] or vim.api.nvim_get_mode().mode)

  local rec = vim.fn.reg_recording()
  add('Recording', rec ~= '' and ('macro into register "%s"'):format(rec) or 'not recording')
  add()

  add('Git branch', vim.b[bufnr].gitsigns_head or '(not tracked)')
  local diff = vim.b[bufnr].gitsigns_status_dict
  if diff and ((diff.added or 0) + (diff.changed or 0) + (diff.removed or 0) > 0) then
    add('Git diff', ('+%d ~%d -%d'):format(diff.added or 0, diff.changed or 0, diff.removed or 0))
  else
    add('Git diff', 'no changes')
  end
  add()

  local sev = vim.diagnostic.severity
  local sev_names = { [sev.ERROR] = 'Error', [sev.WARN] = 'Warning', [sev.INFO] = 'Info', [sev.HINT] = 'Hint' }
  local counts = vim.diagnostic.count(bufnr)
  local total = 0
  for _, n in pairs(counts) do
    total = total + n
  end
  if total == 0 then
    add('Diagnostics', 'none')
  else
    local parts = {}
    for _, level in ipairs { sev.ERROR, sev.WARN, sev.INFO, sev.HINT } do
      if (counts[level] or 0) > 0 then
        table.insert(parts, ('%d %s'):format(counts[level], sev_names[level]))
      end
    end
    add('Diagnostics', table.concat(parts, ', '))
    for _, d in ipairs(vim.diagnostic.get(bufnr)) do
      table.insert(lines, ('  line %d: %s [%s]'):format(d.lnum + 1, d.message:gsub('\n', ' '), d.source or sev_names[d.severity]))
    end
  end
  add()

  local clients = vim.lsp.get_clients { bufnr = bufnr }
  if #clients == 0 then
    add('LSP clients', 'none attached')
  else
    local names = {}
    for _, c in ipairs(clients) do
      table.insert(names, c.name)
    end
    add('LSP clients', table.concat(names, ', '))
  end
  add()

  local name = vim.api.nvim_buf_get_name(bufnr)
  add('File', name ~= '' and name or '[No Name]')
  add('Filetype', vim.bo[bufnr].filetype ~= '' and vim.bo[bufnr].filetype or '(none)')
  add('Encoding', vim.bo[bufnr].fileencoding ~= '' and vim.bo[bufnr].fileencoding or vim.o.encoding)
  add('Fileformat', vim.bo[bufnr].fileformat)
  add('Modified', vim.bo[bufnr].modified and 'yes' or 'no')
  add('Readonly', vim.bo[bufnr].readonly and 'yes' or 'no')
  local ok, stat = pcall(function() return (vim.uv or vim.loop).fs_stat(name) end)
  add('Size', (ok and stat) and bytes_to_human(stat.size) or 'n/a')
  add('Lines', tostring(vim.api.nvim_buf_line_count(bufnr)))
  add()

  add('Location', ('line %d, column %d of %d lines'):format(cursor[1], cursor[2] + 1, vim.api.nvim_buf_line_count(bufnr)))
  if vim.v.hlsearch == 1 then
    local sok, s_count = pcall(vim.fn.searchcount, { recompute = true })
    if sok and s_count.total and s_count.total > 0 then
      add('Search', ('match %d of %d'):format(s_count.current, s_count.total))
    end
  end

  return lines, label_spans
end

local function render()
  if not (buf_id and vim.api.nvim_buf_is_valid(buf_id)) then
    return
  end
  if not (target_bufnr and vim.api.nvim_buf_is_valid(target_bufnr)) then
    -- The buffer this report was about got deleted; nothing sensible left
    -- to show, so just close rather than render garbage.
    M.toggle()
    return
  end
  local lines, label_spans = build_lines(target_bufnr, target_winid)

  vim.bo[buf_id].modifiable = true
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  vim.bo[buf_id].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf_id, -1, 0, -1)
  local ns = vim.api.nvim_create_namespace 'statusline_report'
  for _, span in ipairs(label_spans) do
    vim.hl.range(buf_id, ns, 'Comment', { span.line, 0 }, { span.line, span.col_end })
  end

  -- Autocmd-driven buffer updates (e.g. RecordingLeave firing mid-keystroke)
  -- don't always repaint the terminal until Neovim next goes idle; force it
  -- so the popup never looks stale while it's open.
  vim.cmd 'redraw'
end

local function close()
  vim.api.nvim_clear_autocmds { group = augroup }
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, true)
  end
  win_id, buf_id, target_bufnr, target_winid = nil, nil, nil, nil
end

local function open()
  -- Must capture these before nvim_open_win below switches focus into the
  -- popup -- see the note on target_bufnr/target_winid above.
  target_bufnr = vim.api.nvim_get_current_buf()
  target_winid = vim.api.nvim_get_current_win()

  local width = math.min(90, math.floor(vim.o.columns * 0.7))
  local height = 26

  buf_id = vim.api.nvim_create_buf(false, true)
  vim.bo[buf_id].bufhidden = 'wipe'

  win_id = vim.api.nvim_open_win(buf_id, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Buffer Status ',
    title_pos = 'center',
  })
  vim.wo[win_id].wrap = true
  vim.wo[win_id].linebreak = true

  render()

  for _, key in ipairs { 'q', '<Esc>' } do
    vim.keymap.set('n', key, close, { buffer = buf_id, nowait = true, silent = true })
  end

  -- Keep it live while open, instead of a frozen snapshot -- same idea as
  -- the statusline itself, just refreshed on the events that actually
  -- change what it shows rather than every redraw.
  --
  -- Scheduled rather than called directly: RecordingLeave in particular
  -- fires *before* the recording actually stops (per :h RecordingLeave), so
  -- reg_recording() would still report the register that was just active if
  -- read synchronously inside the callback.
  local function schedule_render()
    vim.schedule(render)
  end
  vim.api.nvim_create_autocmd({
    'CursorMoved',
    'CursorMovedI',
    'ModeChanged',
    'RecordingEnter',
    'RecordingLeave',
    'DiagnosticChanged',
    'LspAttach',
    'LspDetach',
  }, {
    group = augroup,
    callback = schedule_render,
  })
  vim.api.nvim_create_autocmd('User', {
    group = augroup,
    pattern = 'GitSignsUpdate',
    callback = schedule_render,
  })
end

function M.toggle()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    close()
  else
    open()
  end
end

vim.keymap.set('n', '<leader>ts', M.toggle, { desc = '[T]oggle [S]tatusline report' })

return M
