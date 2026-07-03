return {
  -- Main LSP Configuration
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    -- Mason must be loaded before its dependents so we need to set it up here.
    -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
    { 'williamboman/mason.nvim', opts = {} },
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- LSP status updates (workspace loading, indexing, etc.) are bridged
    -- straight into nvim-notify instead -- see custom/plugins/notify.lua --
    -- so fidget.nvim's separate progress window isn't needed here.

    -- Allows extra capabilities provided by nvim-cmp
    'hrsh7th/cmp-nvim-lsp',
  },
  config = function()
    -- Brief aside: **What is LSP?**
    --
    -- LSP is an initialism you've probably heard, but might not understand what it is.
    --
    -- LSP stands for Language Server Protocol. It's a protocol that helps editors
    -- and language tooling communicate in a standardized fashion.
    --
    -- In general, you have a "server" which is some tool built to understand a particular
    -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
    -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
    -- processes that communicate with some "client" - in this case, Neovim!
    --
    -- LSP provides Neovim with features like:
    --  - Go to definition
    --  - Find references
    --  - Autocompletion
    --  - Symbol Search
    --  - and more!
    --
    -- Thus, Language Servers are external tools that must be installed separately from
    -- Neovim. This is where `mason` and related plugins come into play.
    --
    -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
    -- and elegantly composed help section, `:help lsp-vs-treesitter`

    --  This function gets run when an LSP attaches to a particular buffer.
    --    That is to say, every time a new file is opened that is associated with
    --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
    --    function will be executed to configure the current buffer
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        -- NOTE: Remember that Lua is a real programming language, and as such it is possible
        -- to define small helper and utility functions so you don't have to repeat yourself.
        --
        -- In this case, we create a function that lets us more easily define mappings specific
        -- for LSP related items. It sets the mode, buffer and description for us each time.
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        -- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
        ---@param client vim.lsp.Client
        ---@param method vim.lsp.protocol.Method
        ---@param bufnr? integer some lsp support methods only in specific files
        ---@return boolean
        local function client_supports_method(client, method, bufnr)
          if vim.fn.has 'nvim-0.11' == 1 then
            return client:supports_method(method, bufnr)
          else
            return client.supports_method(method, { bufnr = bufnr })
          end
        end

        -- Forward-declared: open_md_popup, show_hover_at, and
        -- setup_nested_hover call each other (a hover popup can trigger
        -- another nested hover popup, and drilling back out reopens a
        -- previous one), so none of them can be a plain `local function`
        -- defined only at its own use site.
        local open_md_popup
        local show_hover_at
        local setup_nested_hover

        -- Because we forcibly focus the hover float (see below), Neovim's
        -- built-in auto-close never fires: it's wired to CursorMoved/BufLeave
        -- on the *source* buffer, and jumping back to the previous window
        -- (<C-w>p, Ctrl-hjkl, etc.) neither moves the cursor nor re-leaves
        -- that buffer if you land back exactly where you started. Closing on
        -- WinLeave of the float's own buffer instead means it closes the
        -- instant focus leaves it, no matter how you left.
        ---@param winid integer floating window id
        ---@param bufnr integer floating window's own buffer
        local function close_float_on_leave(winid, bufnr)
          vim.api.nvim_create_autocmd('WinLeave', {
            buffer = bufnr,
            once = true,
            callback = function()
              vim.schedule(function()
                if vim.api.nvim_win_is_valid(winid) then
                  vim.api.nvim_win_close(winid, true)
                end
              end)
            end,
          })
        end

        -- open_floating_preview anchors horizontally at the cursor's screen
        -- column, extending right, then *flips* to extend left instead if
        -- that would overflow the window -- a corner-flip driven entirely by
        -- content width, so a short doc sits snugly near the cursor while a
        -- long one at the very same cursor position can jump to hug the
        -- opposite edge of the window instead, far from the caret.
        --
        -- Keep it near the caret rather than centering the window (centering
        -- fixed the jump but made every hover appear in the middle of the
        -- window regardless of where you're actually looking, which is
        -- worse for a doc you're reading in place). Instead, keep whatever
        -- left edge Neovim already chose and just slide it the minimum
        -- amount needed to stay fully inside the window -- clamping, not
        -- flipping or recentering.
        --
        -- Left untouched: the *vertical* half of Neovim's placement (row and
        -- the N/S half of anchor). Its anchor_bias='auto' already picks
        -- whichever of above/below the cursor's line has more real estate,
        -- using only the cursor's position -- not content height -- so it's
        -- already stable across different doc sizes and needs no fixing.
        ---@param winid integer floating window to keep on-screen near the caret
        local function keep_float_near_caret(winid)
          local cfg = vim.api.nvim_win_get_config(winid)
          if cfg.relative ~= 'win' then
            return
          end
          local host_width = vim.api.nvim_win_get_width(cfg.win)
          local horiz_anchor = (cfg.anchor or 'NW'):sub(2, 2)
          -- Normalize to a left-edge column regardless of which corner
          -- Neovim anchored to ('E' means cfg.col is the *right* edge).
          local desired_left = horiz_anchor == 'E' and (cfg.col - cfg.width) or cfg.col
          local col = math.max(0, math.min(desired_left, host_width - cfg.width))
          local vert_anchor = (cfg.anchor or 'NW'):sub(1, 1)
          vim.api.nvim_win_set_config(winid, {
            relative = 'win',
            win = cfg.win,
            row = cfg.row,
            col = col,
            width = cfg.width,
            height = cfg.height,
            anchor = vert_anchor .. 'W',
          })
        end

        -- Open a hover float for a given set of already-rendered markdown
        -- lines, focused and wired up for nested navigation. Shared by the
        -- initial nested-hover request (show_hover_at) and by <C-o> "back"
        -- navigation (setup_nested_hover), which reopens a previous level
        -- from its cached lines rather than re-requesting it from the LSP.
        ---@param lines string[]
        ---@param client vim.lsp.Client
        ---@param source_winid integer the real editing window the hover chain started from --
        --- open_floating_preview sizes/positions itself using the *current*
        --- window's winheight()/winline()/wincol(), so calling it while a
        --- nested hover popup is current would clamp the new popup to fit
        --- inside that tiny float. nvim_win_call fools it into measuring
        --- against the real window instead, without changing focus.
        ---@param history table[] stack of popups drilled past on the way here, each { lines, client, source_winid } -- see setup_nested_hover
        open_md_popup = function(lines, client, source_winid, history)
          local hover_bufnr, winid
          local function open()
            hover_bufnr, winid = vim.lsp.util.open_floating_preview(lines, 'markdown', {
              max_width = 200,
              border = 'rounded',
            })
          end
          if vim.api.nvim_win_is_valid(source_winid) then
            vim.api.nvim_win_call(source_winid, open)
          else
            open()
          end
          keep_float_near_caret(winid)
          vim.api.nvim_set_current_win(winid)
          close_float_on_leave(winid, hover_bufnr)
          setup_nested_hover(hover_bufnr, client, source_winid, history)
        end

        -- Request hover at an arbitrary (uri, position) -- not necessarily
        -- where the cursor actually is -- and open it focused, same as the
        -- normal <F1> hover below. Used both for the initial hover and for
        -- "nested" hovers triggered from inside a hover popup (see below).
        ---@param client vim.lsp.Client
        ---@param uri string
        ---@param position lsp.Position
        ---@param source_winid integer see open_md_popup
        ---@param history table[] see setup_nested_hover
        show_hover_at = function(client, uri, position, source_winid, history)
          client:request(vim.lsp.protocol.Methods.textDocument_hover, {
            textDocument = { uri = uri },
            position = position,
          }, function(err, result)
            if err or not result or not result.contents then
              vim.notify('No hover info available', vim.log.levels.INFO)
              return
            end
            local md_lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
            if vim.tbl_isempty(md_lines) then
              vim.notify('No hover info available', vim.log.levels.INFO)
              return
            end
            open_md_popup(md_lines, client, source_winid, history)
          end)
        end

        -- Lets you press <F1> again *inside* a hover popup, on a word
        -- mentioned in its text, to drill into documentation for that word
        -- too. The popup buffer has no file/LSP client of its own, so this
        -- can't do a real position-based hover -- it does a workspace/symbol
        -- search by name instead. A wrong/ambiguous match here (e.g. an
        -- overloaded or shadowed name) is the LSP server's search quality,
        -- not this glue code -- same as any other name-based LSP action.
        ---@param hover_bufnr integer
        ---@param client vim.lsp.Client
        ---@param source_winid integer threaded through to show_hover_at so any depth of nesting still sizes against the real window
        ---@param history table[] stack of popups drilled past, each { lines, client, source_winid }, oldest first -- <C-o> pops the most recent one and reopens it from its cached lines
        setup_nested_hover = function(hover_bufnr, client, source_winid, history)
          -- The floating window inherits source_winid's jumplist on
          -- creation (nvim_open_win behaves like a split for this), so
          -- Vim's native <C-o> would happily jump to a real file location
          -- from *that* jumplist and load it straight into this floating
          -- window -- not "back to the previous doc" at all. Override it to
          -- pop our own hover history instead; a no-op at the top of the
          -- chain rather than falling through to that broken behavior.
          vim.keymap.set('n', '<C-o>', function()
            if #history == 0 then
              return
            end
            local prev = table.remove(history)
            local cur_win = vim.api.nvim_get_current_win()
            if vim.api.nvim_win_is_valid(cur_win) then
              vim.api.nvim_win_close(cur_win, true)
            end
            open_md_popup(prev.lines, prev.client, prev.source_winid, history)
          end, { buffer = hover_bufnr, nowait = true, desc = 'Back to previous hover doc' })

          vim.keymap.set('n', '<F1>', function()
            local word = vim.fn.expand '<cword>'
            if word == '' then
              return
            end
            if not client_supports_method(client, vim.lsp.protocol.Methods.workspace_symbol) then
              vim.notify('LSP server does not support workspace symbol search', vim.log.levels.WARN)
              return
            end
            client:request(vim.lsp.protocol.Methods.workspace_symbol, { query = word }, function(err, results)
              if err or not results or #results == 0 then
                vim.notify('No symbol found for "' .. word .. '"', vim.log.levels.INFO)
                return
              end
              local sym = results[1]
              local loc = sym.location

              local function drill_to(uri, position)
                table.insert(history, {
                  lines = vim.api.nvim_buf_get_lines(hover_bufnr, 0, -1, false),
                  client = client,
                  source_winid = source_winid,
                })
                show_hover_at(client, uri, position, source_winid, history)
              end

              if loc.range then
                drill_to(loc.uri, loc.range.start)
              elseif client_supports_method(client, vim.lsp.protocol.Methods.workspaceSymbol_resolve) then
                client:request(vim.lsp.protocol.Methods.workspaceSymbol_resolve, sym, function(rerr, resolved)
                  if rerr or not resolved or not resolved.location.range then
                    vim.notify('Could not resolve location for "' .. word .. '"', vim.log.levels.INFO)
                    return
                  end
                  drill_to(resolved.location.uri, resolved.location.range.start)
                end)
              else
                vim.notify('Symbol location has no range and server cannot resolve it', vim.log.levels.INFO)
              end
            end)
          end, { buffer = hover_bufnr, desc = 'Hover doc for symbol under cursor (workspace search)' })
        end

        -- Show hover documentation for the symbol under your cursor.
        -- Neovim already binds this to `K` by default; this just adds a
        -- second, more IntelliJ-familiar way to trigger the same thing.
        -- max_width caps it at 200 columns instead of stretching across the
        -- whole window for long docs.
        --
        -- vim.lsp.util.open_floating_preview (which hover uses) hardcodes
        -- `enter = false` when creating the window, so it's never focused on
        -- first open no matter what config is passed -- there's no built-in
        -- option for this. Poll for the window it creates (stored as
        -- vim.b[bufnr].lsp_floating_preview once the async hover response
        -- lands) and focus it ourselves as soon as it exists, then wire up
        -- nested hover navigation inside it too.
        map('<F1>', function()
          local bufnr = vim.api.nvim_get_current_buf()
          local source_winid = vim.api.nvim_get_current_win()
          local clients = vim.lsp.get_clients { bufnr = bufnr }
          vim.lsp.buf.hover { max_width = 100, border = 'rounded' }

          local tries = 0
          local function try_focus()
            tries = tries + 1
            local win = vim.b[bufnr].lsp_floating_preview
            if win and vim.api.nvim_win_is_valid(win) then
              keep_float_near_caret(win)
              vim.api.nvim_set_current_win(win)
              local hover_bufnr = vim.api.nvim_win_get_buf(win)
              close_float_on_leave(win, hover_bufnr)
              if clients[1] then
                setup_nested_hover(hover_bufnr, clients[1], source_winid, {})
              end
            elseif tries < 10 then
              vim.defer_fn(try_focus, 30)
            end
          end
          vim.defer_fn(try_focus, 30)
        end, 'Hover Documentation (focused)')

        -- Rename the variable under your cursor.
        --  Most Language Servers support renaming across files, etc.
        map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

        -- Find references for the word under your cursor.
        map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

        -- Jump to the implementation of the word under your cursor.
        --  Useful when your language has ways of declaring types without an actual implementation.
        map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

        -- Jump to the definition of the word under your cursor.
        --  This is where a variable was first declared, or where a function is defined, etc.
        --  To jump back, press <C-t>.
        map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -- Fuzzy find all the symbols in your current document.
        --  Symbols are things like variables, functions, types, etc.
        map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')

        -- Fuzzy find all the symbols in your current workspace.
        --  Similar to document symbols, except searches over your entire project.
        map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')

        -- Jump to the type of the word under your cursor.
        --  Useful when you're not sure what type a variable is and you want to see
        --  the definition of its *type*, not where it was *defined*.
        map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

        -- (client_supports_method is defined earlier in this callback now,
        -- alongside the F1 hover/nested-hover setup that also needs it.)

        -- The following two autocommands are used to highlight references of the
        -- word under your cursor when your cursor rests there for a little while.
        --    See `:help CursorHold` for information about when this is executed
        --
        -- When you move your cursor, the highlights will be cleared (the second autocommand).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -- The following code creates a keymap to toggle inlay hints in your
        -- code, if the language server you are using supports them
        --
        -- This may be unwanted, since they displace some of your code
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    -- Diagnostic Config
    -- See :help vim.diagnostic.Opts
    vim.diagnostic.config {
      severity_sort = true,
      float = { border = 'rounded', source = 'if_many' },
      underline = { severity = vim.diagnostic.severity.ERROR },
      signs = vim.g.have_nerd_font and {
        text = {
          [vim.diagnostic.severity.ERROR] = '󰅚 ',
          [vim.diagnostic.severity.WARN] = '󰀪 ',
          [vim.diagnostic.severity.INFO] = '󰋽 ',
          [vim.diagnostic.severity.HINT] = '󰌶 ',
        },
      } or {},
      virtual_text = {
        source = 'if_many',
        spacing = 2,
        format = function(diagnostic)
          local diagnostic_message = {
            [vim.diagnostic.severity.ERROR] = diagnostic.message,
            [vim.diagnostic.severity.WARN] = diagnostic.message,
            [vim.diagnostic.severity.INFO] = diagnostic.message,
            [vim.diagnostic.severity.HINT] = diagnostic.message,
          }
          return diagnostic_message[diagnostic.severity]
        end,
      },
    }

    -- LSP servers and clients are able to communicate to each other what features they support.
    --  By default, Neovim doesn't support everything that is in the LSP specification.
    --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
    --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

    -- Enable the following language servers
    --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
    --
    --  Add any additional override configuration in the following tables. Available keys are:
    --  - cmd (table): Override the default command used to start the server
    --  - filetypes (table): Override the default list of associated filetypes for the server
    --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
    --  - settings (table): Override the default settings passed when initializing the server.
    --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
    local servers = {
      ['postgres-language-server'] = {
        cmd = { 'postgres-language-server', 'lsp-proxy' },
      },

      gopls = {},

      yamlls = {},

      lua_ls = {
        -- cmd = { ... },
        -- filetypes = { ... },
        -- capabilities = {},
        settings = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
            -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
            diagnostics = { disable = { 'missing-fields' } },
          },
        },
      },
    }

    -- Ensure the servers and tools above are installed
    --
    -- To check the current status of installed tools and/or manually install
    -- other tools, you can run
    --    :Mason
    --
    -- You can press `g?` for help in this menu.
    --
    -- `mason` had to be setup earlier: to configure its options see the
    -- `dependencies` table for `nvim-lspconfig` above.
    --
    -- You can add other tools here that you want Mason to install
    -- for you, so that they are available from within Neovim.
    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, {
      'stylua', -- Used to format Lua code
    })
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    require('mason-lspconfig').setup {
      ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
      automatic_installation = false,
      handlers = {
        function(server_name)
          local server = servers[server_name] or {}
          -- This handles overriding only values explicitly passed
          -- by the server configuration above. Useful when disabling
          -- certain features of an LSP (for example, turning off formatting for ts_ls)
          server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
          require('lspconfig')[server_name].setup(server)
        end,
      },
    }
  end,
}
