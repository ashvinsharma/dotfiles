-- [[ <leader>mp: render the current Graphviz buffer to SVG and open it ]]
-- Mirrors markdown-preview.nvim's <leader>mp mnemonic, scoped to `dot`
-- buffers. Renders live buffer content (not the file on disk, so unsaved
-- edits show up) via stdin, so no scratch source file is needed -- only the
-- rendered SVG lands in /tmp, timestamped so repeated previews never
-- clobber each other or overwrite a previous render you still have open.

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'dot',
  callback = function(args)
    vim.keymap.set('n', '<leader>mp', function()
      if vim.fn.executable 'dot' == 0 then
        vim.notify('Graphviz `dot` not found on PATH', vim.log.levels.ERROR)
        return
      end

      local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ':t:r')
      if name == '' then
        name = 'graph'
      end
      local out = string.format('/tmp/%s-%s.svg', name, os.date '%Y%m%d-%H%M%S')

      local source = table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, -1, false), '\n')
      vim.fn.system({ 'dot', '-Tsvg', '-o', out }, source)
      if vim.v.shell_error ~= 0 then
        vim.notify('dot render failed (exit ' .. vim.v.shell_error .. ')', vim.log.levels.ERROR)
        return
      end

      vim.fn.jobstart({ 'open', out }, { detach = true })
      vim.notify('Rendered ' .. out)
    end, { buffer = args.buf, desc = '[M]arkdown/graphviz [P]review' })
  end,
})
