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

    -- Simple and easy statusline.
    --  You could remove this setup call if you don't like it,
    --  and try some other statusline plugin
    local statusline = require 'mini.statusline'

    -- set use_icons to true if you have a Nerd Font
    statusline.setup {
      use_icons = vim.g.have_nerd_font,
      content = {
        active = function()
          local mode, mode_hl = MiniStatusline.section_mode { trunc_width = 120 }
          local git = MiniStatusline.section_git { trunc_width = 40 }
          local lsp = MiniStatusline.section_lsp { trunc_width = 75 }
          -- trunc_width = math.huge forces these two into their own
          -- built-in "truncated" short forms: relative path only (no full
          -- absolute path), and icon+filetype only (no encoding/fileformat/
          -- size, which are only useful when non-default and were always-on
          -- noise otherwise).
          local filename = MiniStatusline.section_filename { trunc_width = math.huge }
          local location = MiniStatusline.section_location { trunc_width = 75 }
          local search = MiniStatusline.section_searchcount { trunc_width = 75 }

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
          vim.list_extend(groups, diag_groups)
          vim.list_extend(groups, {
            { hl = 'MiniStatuslineDevinfo', strings = { lsp } },
            '%<',
            { hl = 'MiniStatuslineFilename', strings = { filename } },
            '%=',
            { hl = file_icon_hl or 'MiniStatuslineFileinfo', strings = { file_icon } },
            { hl = 'MiniStatuslineFileinfo', strings = { vim.bo.filetype } },
            { hl = mode_hl, strings = { search, location } },
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
