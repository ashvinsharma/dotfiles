return { -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  main = 'nvim-treesitter.configs', -- Sets main module to use for opts
  -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
  opts = {
    ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc', 'ruby', 'go', 'yaml', 'terraform', 'dot' },
    -- Autoinstall languages that are not installed
    auto_install = true,
    highlight = {
      enable = true,
      -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
      --  If you are experiencing weird indenting issues, add the language to
      --  the list of additional_vim_regex_highlighting and disabled languages for indent.
      additional_vim_regex_highlighting = { 'ruby' },
    },
    indent = { enable = true, disable = { 'ruby' } },
  },
  config = function(_, opts)
    require('nvim-treesitter.configs').setup(opts)

    -- Neovim 0.12 query predicates can hand a directive a *list* of nodes
    -- for a capture instead of a single node. nvim-treesitter's `master`
    -- branch is frozen/archived and its query_predicates.lua still assumes
    -- a single node, so it crashes with "attempt to call method 'range'
    -- (a nil value)" -- most visibly on markdown fenced-code-block
    -- injections (e.g. via render-markdown.nvim).
    -- https://github.com/nvim-treesitter/nvim-treesitter/issues/8636
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
