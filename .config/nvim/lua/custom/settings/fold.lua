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
-- without this function, tabs were converted to spaces in vim.opt.foldtext
-- this was an issue in languages where tabs are used instead of spaces like
-- golang.
_G.CustomFoldText = function()
  local line = vim.fn.getline(vim.v.foldstart)
  local expanded_line = vim.fn.substitute(line, '\t', string.rep(' ', vim.opt.tabstop:get()), 'g')
  local indentation = expanded_line:match '^%s*'

  local start_text = vim.fn.trim(line)
  local end_text = vim.fn.trim(vim.fn.getline(vim.v.foldend))

  return indentation .. start_text .. '...' .. end_text
end
vim.opt.foldtext = 'v:lua.CustomFoldText()'

-- remove the trailing characters after vim.opt.foldtext
vim.opt.fillchars:append { fold = ' ' }
