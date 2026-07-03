-- Floating "what does this icon mean" reference for the mini.statusline
-- layout configured in custom/plugins/mini-vim.lua. Toggle with <leader>ts.

local M = {}

local win_id = nil

local lines = {
  '# Statusline Legend',
  '',
  'Left to right, this is what each part of the bottom bar means.',
  '',
  '## Mode (leftmost)',
  '',
  '| Shown as  | Mode         |',
  '|-----------|--------------|',
  '| `Normal`  | Normal mode  |',
  '| `Insert`  | Insert mode  |',
  '| `Visual`  | Visual (charwise) |',
  '| `V-Line`  | Visual line-wise |',
  '| `V-Block` | Visual block-wise |',
  '| `Select`  | Select mode |',
  '| `Replace` | Replace mode (`R`) |',
  '| `Command` | Command-line mode |',
  '| `Terminal`| Inside a `:terminal` buffer |',
  '',
  '## REC @<register>',
  '',
  'Only appears while recording a macro (after pressing `q<letter>`).',
  'Shows which register the macro is being recorded into, e.g. `REC @a`',
  'means everything you do next is being recorded into register `a` until',
  'you press `q` again to stop. Easy to forget you left this running --',
  'that is the entire reason this indicator was added.',
  '',
  '## Git & diff',
  '',
  '| Symbol      | Meaning |',
  '|-------------|---------|',
  '| `master`, `main`, branch name | Current git branch (or detached HEAD ref) |',
  '| `+N`        | N lines added since the last commit |',
  '| `~N`        | N lines changed since the last commit |',
  '| `-N`        | N lines removed since the last commit |',
  '',
  'These come from gitsigns. Use `<leader>g*` keybinds to act on them',
  '(stage/reset/preview a hunk), or `]c` / `[c` to jump directly to the',
  'next/previous changed hunk.',
  '',
  '## Diagnostics',
  '',
  '| Icon | Severity |',
  '|------|----------|',
  '| 󰅚    | Error   |',
  '| 󰀪    | Warning |',
  '| 󰋽    | Info    |',
  '| 󰌶    | Hint    |',
  '',
  'These are the exact same icons used in the sign-column gutter next to',
  'the line numbers (defined once in nvim-lspconfig.lua and reused here),',
  'so a warning looks identical whether you spot it in the gutter or down',
  'here in the statusline.',
  '',
  'Followed by a count, e.g. `E2 W1` means 2 errors and 1 warning in the',
  'current buffer. Nothing is shown at all when there are zero diagnostics.',
  'Use `<leader>sd` to search all diagnostics, or `<leader>q` to put them',
  'in the quickfix list.',
  '',
  '## LSP',
  '',
  '`󰰎 +` (or `LSP +` without a Nerd Font) -- one `+` per language server',
  'attached to the current buffer. No icon at all means no LSP is attached',
  '(check `:LspInfo` if you expected one to be running).',
  '',
  '## Filename & filetype',
  '',
  'Shown as a relative path (not the full absolute path) with modified',
  '(`+`) and readonly (`[RO]`) flags appended when applicable, followed by',
  'just the filetype name/icon -- encoding, line-ending, and file size are',
  'intentionally left out since they are only ever interesting when they',
  'are NOT the boring default (utf-8, unix). Nothing here tells you that.',
  '',
  '## Location & search (rightmost)',
  '',
  '`<line>:<column>` for cursor position. While an active `/search` has',
  'matches, a `[current/total]` count also appears just before it.',
  '',
  '---',
  'Press q or <Esc> to close this window.',
}

local function close()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, true)
  end
  win_id = nil
end

local function open()
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.8))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  win_id = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Statusline Legend ',
    title_pos = 'center',
  })

  vim.wo[win_id].wrap = true
  vim.wo[win_id].linebreak = true

  for _, key in ipairs { 'q', '<Esc>' } do
    vim.keymap.set('n', key, close, { buffer = buf, nowait = true, silent = true })
  end
end

function M.toggle()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    close()
  else
    open()
  end
end

vim.keymap.set('n', '<leader>ts', M.toggle, { desc = '[T]oggle [S]tatusline legend' })

return M
