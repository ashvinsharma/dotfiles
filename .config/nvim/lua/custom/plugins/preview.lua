return {
  {
    'selimacerbas/markdown-preview.nvim',
    dependencies = { 'selimacerbas/live-server.nvim' },
    ft = { 'markdown' },
    config = function()
      require('markdown_preview').setup {
        browser = 'Arc',
      }

      vim.keymap.set('n', '<leader>tp', '<cmd>MarkdownPreview<CR>', { desc = '[T]oggle [P]review' })
    end,
  },
}
