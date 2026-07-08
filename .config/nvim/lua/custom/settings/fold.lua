-- NOTE: Curently this uses treesitter to understand the folds. I am using
-- https://www.jackfranklin.co.uk/blog/code-folding-in-vim-neovim/
vim.opt.foldmethod = 'expr'
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
-- Set this to "1" to create a + gutter (column) beside the line number column
vim.opt.foldcolumn = '0'
-- no need for a summary instead show the first line of the fold
vim.opt.foldtext = ''
-- fold no more than N level
vim.opt.foldnestmax = 9
-- start folding after N level
vim.opt.foldlevelstart = 5
-- change fold text to the first and the last line with ellipses in between
-- without expanding tabs ourselves, they were converted to spaces by
-- vim.opt.foldtext's plain-string handling -- an issue in languages where
-- tabs are used instead of spaces like golang.
local tabstop = vim.opt.tabstop:get()
local function expand_tabs(text)
  return (text:gsub('\t', string.rep(' ', tabstop)))
end

-- Returning a List (instead of a string) from 'foldtext' makes Neovim draw
-- it like overlay virtual text, i.e. each {text, hlgroup} chunk keeps its
-- own highlight instead of the whole line being flattened to one color
-- (the default 'Folded' grey, indistinguishable from a comment). This
-- walks a line column-by-column via treesitter to rebuild it as chunks
-- with their real, theme-colored highlight groups, trimmed like
-- vim.fn.trim() trimmed the plain-string version.
local function line_chunks(bufnr, lnum)
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ''
  local first, last = line:find '%S.*%S'
  if not first then
    first, last = line:find '%S'
    last = last or 0
  end
  local chunks = {}
  local chunk_hl, chunk_start = nil, first - 1
  for col = chunk_start, last - 1 do
    local captures = vim.treesitter.get_captures_at_pos(bufnr, lnum, col)
    -- last entry is the most specific (innermost) capture at this column
    local cap = captures[#captures]
    local hl = cap and ('@' .. cap.capture .. '.' .. cap.lang) or nil
    if hl ~= chunk_hl then
      if col > chunk_start then
        table.insert(chunks, { expand_tabs(line:sub(chunk_start + 1, col)), chunk_hl })
      end
      chunk_start, chunk_hl = col, hl
    end
  end
  if chunk_start < last then
    table.insert(chunks, { expand_tabs(line:sub(chunk_start + 1, last)), chunk_hl })
  end
  return chunks
end

_G.CustomFoldText = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local indentation = expand_tabs(vim.fn.getline(vim.v.foldstart)):match '^%s*'

  local chunks = { { indentation } }
  vim.list_extend(chunks, line_chunks(bufnr, vim.v.foldstart - 1))
  table.insert(chunks, { ' ... ', '@comment' })
  vim.list_extend(chunks, line_chunks(bufnr, vim.v.foldend - 1))

  return chunks
end
vim.opt.foldtext = 'v:lua.CustomFoldText()'

-- remove the trailing characters after vim.opt.foldtext
vim.opt.fillchars:append { fold = ' ' }

-- l/e/E are deliberate "step into this exact spot" motions -- unlike j/k
-- (pure vertical scanning, fine to leave a fold closed for), pressing one of
-- these means you want to actually reach text at/after the cursor. But
-- 'foldopen' (which already includes "hor" for horizontal motions) only
-- auto-opens a fold when a motion newly crosses INTO it; if you're already
-- sitting on the fold's collapsed line (landed there via j/k), Vim doesn't
-- consider l/e/E from here to be "entering" it, so they silently do nothing
-- useful -- the real line only has as much text as the actual first line of
-- the fold, not the extra content the foldtext above appends after " ... ".
-- zv ("view cursor line": open just enough folds to un-fold the cursor's
-- line) is a no-op when the cursor isn't on a closed fold, so prefixing it
-- unconditionally is safe. v:count1 is re-inserted so counts like `3l`/`2e`
-- still work.
for _, key in ipairs { 'l', 'e', 'E' } do
  vim.keymap.set('n', key, function()
    return 'zv' .. vim.v.count1 .. key
  end, { expr = true, desc = 'Open fold under cursor, then ' .. key })
end
