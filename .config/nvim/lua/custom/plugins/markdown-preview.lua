return {
  'iamcco/markdown-preview.nvim',
  cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
  ft = { 'markdown' },
  build = function()
    vim.fn['mkdp#util#install']()
  end,
  config = function()
    -- The preview server reads buffer content directly (no render hook
    -- exists to transform it), so the only way to get a `[toc]` marker into
    -- the preview without permanently adding it to the file is to insert it
    -- into the live buffer for the duration of the preview and remove it
    -- again on close. Tracked with an extmark so it stays correct even if
    -- the buffer is edited above/below it while previewing.
    local toc_ns = vim.api.nvim_create_namespace 'mkdp_toc'

    local function has_toc_marker(bufnr)
      for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        if line:match '%${toc}' or line:match '%[%[?_?toc_?%]?%]' then
          return true
        end
      end
      return false
    end

    local function inject_toc(bufnr)
      if has_toc_marker(bufnr) then
        return
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { '[toc]', '' })
      vim.b[bufnr].mkdp_toc_mark = vim.api.nvim_buf_set_extmark(bufnr, toc_ns, 0, 0, { end_row = 2, end_col = 0 })
    end

    local function remove_injected_toc(bufnr)
      local mark_id = vim.b[bufnr].mkdp_toc_mark
      if not mark_id then
        return
      end
      local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, toc_ns, mark_id, { details = true })
      if pos and pos[1] and pos[3] then
        vim.api.nvim_buf_set_lines(bufnr, pos[1], pos[3].end_row, false, {})
      end
      pcall(vim.api.nvim_buf_del_extmark, bufnr, toc_ns, mark_id)
      vim.b[bufnr].mkdp_toc_mark = nil
    end

    -- mkdp#util#toggle_preview() tracks its own open/closed state in
    -- b:MarkdownPreviewToggleBool -- read it *before* toggling to know
    -- whether this call is about to open (inject first) or close (remove
    -- after).
    vim.keymap.set('n', '<leader>mp', function()
      if vim.bo.filetype ~= 'markdown' then
        return
      end
      local bufnr = vim.api.nvim_get_current_buf()
      local opening = vim.b[bufnr].MarkdownPreviewToggleBool ~= 1
      if opening then
        inject_toc(bufnr)
      end
      vim.fn['mkdp#util#toggle_preview']()
      if not opening then
        remove_injected_toc(bufnr)
      end
    end, { desc = 'Toggle [M]arkdown [P]review (with floating TOC)' })
  end,
}
