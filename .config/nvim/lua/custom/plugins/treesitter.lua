return { -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  branch = 'main', -- `master` is frozen/archived; all parser+query updates land on `main` now.
  lazy = false, -- main branch does not support lazy-loading.
  build = ':TSUpdate',
  config = function()
    local ts = require 'nvim-treesitter'
    ts.setup {}

    local languages =
      { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc', 'ruby', 'go', 'yaml', 'terraform', 'dot' }
    ts.install(languages)

    -- Filetype -> treesitter language, wherever they don't already match
    -- (main's vim.treesitter.start() needs the exact parser name).
    -- luadoc/markdown_inline are injection-only parsers with no filetype of
    -- their own, so they're installed above but have no entry here.
    local ft_to_lang = {
      sh = 'bash',
      c = 'c',
      diff = 'diff',
      html = 'html',
      lua = 'lua',
      markdown = 'markdown',
      query = 'query',
      vim = 'vim',
      help = 'vimdoc',
      ruby = 'ruby',
      go = 'go',
      yaml = 'yaml',
      terraform = 'terraform',
      dot = 'dot',
    }

    vim.api.nvim_create_autocmd('FileType', {
      pattern = vim.tbl_keys(ft_to_lang),
      callback = function(args)
        vim.treesitter.start(args.buf, ft_to_lang[vim.bo[args.buf].filetype])
      end,
    })

    -- Treesitter-based indent for everything except ruby, which keeps its
    -- native (non-treesitter) indentexpr -- mirrors the old
    -- `indent.disable = { 'ruby' }` config. Vim's own regex-based syntax
    -- highlighting for ruby (previously `additional_vim_regex_highlighting
    -- = { 'ruby' }`) needs no equivalent here: vim.treesitter.start()
    -- doesn't touch `syntax`, so it already runs alongside treesitter
    -- highlighting by default.
    local indent_fts = vim.tbl_filter(function(ft)
      return ft ~= 'ruby'
    end, vim.tbl_keys(ft_to_lang))

    vim.api.nvim_create_autocmd('FileType', {
      pattern = indent_fts,
      callback = function(args)
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })

    -- Neovim 0.12 query predicates can hand a directive a *list* of nodes
    -- for a capture instead of a single node. This broke nvim-treesitter's
    -- OWN bundled directive handlers on the (frozen) `master` branch, which
    -- still assumed a single node -- https://github.com/nvim-treesitter/nvim-treesitter/issues/8636.
    -- `master`'s query_predicates.lua doesn't exist on `main` at all (the
    -- whole module was dropped in the rewrite), so this specific crash path
    -- can't happen anymore, but these custom directives are still what
    -- nvim-treesitter's bundled markdown/html injection queries call by
    -- name to resolve fenced-code-block/script-tag languages, so the
    -- overrides themselves are still needed -- only the "why" (crash
    -- workaround) is gone, not the directives' purpose.
    local query = require 'vim.treesitter.query'

    local function get_node(match, id)
      local val = match[id]
      if type(val) == 'table' then
        return val[1]
      end
      return val
    end

    local html_script_type_languages = {
      importmap = 'json',
      module = 'javascript',
      ['application/ecmascript'] = 'javascript',
      ['text/ecmascript'] = 'javascript',
    }

    local non_filetype_match_injection_language_aliases = {
      ex = 'elixir',
      pl = 'perl',
      sh = 'bash',
      uxn = 'uxntal',
      ts = 'typescript',
    }

    local function get_parser_from_markdown_info_string(injection_alias)
      local match = vim.filetype.match { filename = 'a.' .. injection_alias }
      return match or non_filetype_match_injection_language_aliases[injection_alias] or injection_alias
    end

    query.add_directive('set-lang-from-mimetype!', function(match, _, bufnr, pred, metadata)
      local node = get_node(match, pred[2])
      if not node then
        return
      end
      local type_attr_value = vim.treesitter.get_node_text(node, bufnr)
      local configured = html_script_type_languages[type_attr_value]
      if configured then
        metadata['injection.language'] = configured
      else
        local parts = vim.split(type_attr_value, '/', {})
        metadata['injection.language'] = parts[#parts]
      end
    end, { force = true })

    query.add_directive('set-lang-from-info-string!', function(match, _, bufnr, pred, metadata)
      local node = get_node(match, pred[2])
      if not node then
        return
      end
      local injection_alias = vim.treesitter.get_node_text(node, bufnr):lower()
      metadata['injection.language'] = get_parser_from_markdown_info_string(injection_alias)
    end, { force = true })

    query.add_directive('downcase!', function(match, _, bufnr, pred, metadata)
      local id = pred[2]
      local node = get_node(match, id)
      if not node then
        return
      end
      local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ''
      if not metadata[id] then
        metadata[id] = {}
      end
      metadata[id].text = string.lower(text)
    end, { force = true })
  end,
  -- There are additional nvim-treesitter modules that you can use to interact
  -- with nvim-treesitter. You should go explore a few and see what interests you:
  --
  --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
  --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
}
