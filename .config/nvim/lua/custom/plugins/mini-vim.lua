return { -- Collection of various small independent plugins/modules
  'echasnovski/mini.nvim',
  config = function()
    -- Better Around/Inside textobjects
    --
    -- Examples:
    --  - va)  - [V]isually select [A]round [)]paren
    --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
    --  - ci'  - [C]hange [I]nside [']quote
    require('mini.ai').setup { n_lines = 500 }

    -- Add/delete/replace surroundings (brackets, quotes, etc.)
    --
    -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
    -- - sd'   - [S]urround [D]elete [']quotes
    -- - sr)'  - [S]urround [R]eplace [)] [']
    require('mini.surround').setup()

    -- Animates cursor movement, scrolling (Ctrl-D/U/F/B, gg/G, etc.),
    -- window resize, and open/close -- Neovim jumps these instantly with no
    -- easing by default, which feels rough. Defaults enable all of the
    -- above; see :h MiniAnimate.config to disable any of them individually.
    --
    -- Choppy specifically inside tmux without ~/.tmux.conf declaring the
    -- "sync" terminal-feature for Ghostty (batches rapid redraws into one
    -- atomic paint) -- see the comment there.
    require('mini.animate').setup()

    -- Highlights every other occurrence of the word under the cursor
    -- (MiniCursorword, underline by default) after a short delay, so
    -- moving off a word doesn't leave stale highlights behind.
    require('mini.cursorword').setup()

    -- Highlights TODO/FIXME/HACK/NOTE in comments (replaces
    -- folke/todo-comments.nvim, which was only used for this) plus a color
    -- swatch on hex color codes wherever they appear (CSS, configs, etc.).
    require('mini.hipatterns').setup {
      highlighters = {
        fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
        hack = { pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' },
        todo = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
        note = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },
        hex_color = require('mini.hipatterns').gen_highlighter.hex_color(),
      },
    }

    -- Simple and easy statusline.
    --  You could remove this setup call if you don't like it,
    --  and try some other statusline plugin
    local statusline = require 'mini.statusline'

    -- Filename relative to the buffer's git project root (nearest upward
    -- .git, so submodules/worktrees resolve to their own root) instead of
    -- cwd-relative, since cwd isn't always the project root. Falls back to
    -- the absolute path outside of a git repo. Root lookup is
    -- filesystem-only (no git subprocess per redraw) and cached per buffer
    -- since it can't change for an existing buffer.
    local function relative_to_git_root(bufnr)
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name == '' then
        return '[No Name]'
      end
      if vim.b[bufnr].statusline_git_root == nil then
        local dot_git = vim.fs.find('.git', { path = vim.fs.dirname(name), upward = true })[1]
        vim.b[bufnr].statusline_git_root = dot_git and vim.fs.dirname(dot_git) or false
      end
      local root = vim.b[bufnr].statusline_git_root
      return root and (vim.fs.relpath(root, name) or name) or name
    end

    -- Current line / total lines as a percentage, distinct from location's
    -- line:col -- how far down the buffer the cursor is, not where on the
    -- line. mini.statusline's returned string gets rescanned by Vim's
    -- statusline engine for %-codes (that's how it switches highlight
    -- groups inline), so a literal "%" must be doubled here or Vim
    -- swallows it instead of displaying it.
    local function scroll_percent()
      local total_lines = vim.api.nvim_buf_line_count(0)
      local cur_line = vim.api.nvim_win_get_cursor(0)[1]
      return string.format('%d%%%%', math.floor(cur_line / total_lines * 100))
    end

    -- set use_icons to true if you have a Nerd Font
    statusline.setup {
      use_icons = vim.g.have_nerd_font,
      content = {
        active = function()
          local mode, mode_hl = MiniStatusline.section_mode { trunc_width = 120 }
          local git = MiniStatusline.section_git { trunc_width = 40 }
          local lsp = MiniStatusline.section_lsp { trunc_width = 75 }
          local filename = relative_to_git_root(0)
          local location = MiniStatusline.section_location { trunc_width = 75 }
          local search = MiniStatusline.section_searchcount { trunc_width = 75 }
          local scroll = scroll_percent()

          local recording_register = vim.fn.reg_recording()
          local recording = recording_register ~= '' and ('REC @' .. recording_register) or ''

          -- Diff as individually-colored segments (green add / yellow change
          -- / red delete) using the same GitSigns* highlight groups as the
          -- sign-column gutter, instead of one flat-colored blob.
          local diff_groups = {}
          if not MiniStatusline.is_truncated(75) then
            local diff_summary = vim.b.minidiff_summary or vim.b.gitsigns_status_dict
            if diff_summary then
              if (diff_summary.added or 0) > 0 then
                table.insert(diff_groups, { hl = 'GitSignsAdd', strings = { '+' .. diff_summary.added } })
              end
              if (diff_summary.changed or 0) > 0 then
                table.insert(diff_groups, { hl = 'GitSignsChange', strings = { '~' .. diff_summary.changed } })
              end
              if (diff_summary.removed or 0) > 0 then
                table.insert(diff_groups, { hl = 'GitSignsDelete', strings = { '-' .. diff_summary.removed } })
              end
            end
          end

          -- Diagnostics as individually-colored segments (red error / yellow
          -- warning / blue info / cyan hint), reusing the exact same
          -- Diagnostic* highlight groups and icons as the sign-column gutter
          -- (defined in nvim-lspconfig.lua's vim.diagnostic.config) -- so a
          -- warning looks the same wherever you spot it, and severity is
          -- visible at a glance instead of one flat color for everything.
          local diag_groups = {}
          if not MiniStatusline.is_truncated(75) then
            local diag_signs_text = (vim.diagnostic.config().signs or {}).text or {}
            local counts = vim.diagnostic.count(0)
            for _, item in ipairs {
              { sev = vim.diagnostic.severity.ERROR, hl = 'DiagnosticError' },
              { sev = vim.diagnostic.severity.WARN, hl = 'DiagnosticWarn' },
              { sev = vim.diagnostic.severity.INFO, hl = 'DiagnosticInfo' },
              { sev = vim.diagnostic.severity.HINT, hl = 'DiagnosticHint' },
            } do
              local n = counts[item.sev]
              if n and n > 0 then
                local icon = diag_signs_text[item.sev] or ''
                table.insert(diag_groups, { hl = item.hl, strings = { icon .. n } })
              end
            end
          end

          -- Filetype icon in its own segment with the icon's *real* devicon
          -- color (e.g. Go's cyan), instead of mini.statusline's default
          -- section_fileinfo, which only fetches the bare glyph (no color)
          -- and renders it in the same flat gray as everything else in
          -- MiniStatuslineFileinfo.
          local file_icon, file_icon_hl = '', nil
          if vim.g.have_nerd_font and vim.bo.filetype ~= '' then
            local ok, devicons = pcall(require, 'nvim-web-devicons')
            if ok then
              file_icon, file_icon_hl = devicons.get_icon(vim.fn.expand '%:t', nil, { default = true })
            end
          end

          local groups = {
            { hl = mode_hl, strings = { mode } },
            { hl = 'DiagnosticWarn', strings = { recording } },
            { hl = 'MiniStatuslineDevinfo', strings = { git } },
          }
          vim.list_extend(groups, diff_groups)
          vim.list_extend(groups, {
            '%<',
            { hl = 'MiniStatuslineFilename', strings = { filename } },
          })
          -- Everything past here is right-aligned: diagnostic counts, LSP
          -- clients, then the filetype devicon, then cursor location and
          -- scroll %.
          vim.list_extend(groups, { '%=' })
          vim.list_extend(groups, diag_groups)
          vim.list_extend(groups, {
            { hl = 'MiniStatuslineDevinfo', strings = { lsp } },
            { hl = file_icon_hl or 'MiniStatuslineFileinfo', strings = { file_icon } },
            { hl = 'MiniStatuslineFileinfo', strings = { vim.bo.filetype } },
            { hl = mode_hl, strings = { search, location, scroll } },
          })

          return MiniStatusline.combine_groups(groups)
        end,
      },
    }

    -- You can configure sections in the statusline by overriding their
    -- default behavior. For example, here we set the section for
    -- cursor location to LINE:COLUMN
    ---@diagnostic disable-next-line: duplicate-set-field
    statusline.section_location = function()
      return '%2l:%-2v'
    end

    -- ... and there is more!
    --  Check out: https://github.com/echasnovski/mini.nvim
  end,
}
