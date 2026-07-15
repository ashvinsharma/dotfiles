vim.keymap.set('n', '<leader>tp', function()
  local fn = previewers[vim.bo.filetype]
  if not fn then
    vim.notify('No preview available for filetype: ' .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end
  fn()
end, { desc = '[T]oggle [P]review' })

return {
  {
    'selimacerbas/markdown-preview.nvim',
    dependencies = { 'selimacerbas/live-server.nvim' },
    ft = { 'markdown' },
    config = function()
      require('markdown_preview').setup {}
    end,
  },
}
