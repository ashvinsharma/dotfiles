return {
  'EdenEast/nightfox.nvim',
  priority = 1000,
  config = function()
    local colors = require 'custom.colors'
    require('nightfox').setup {
      options = {
        transparent = true,
      },
      groups = {
        all = {
          NormalFloat = { bg = colors.surface0 },
          FloatBorder = { bg = colors.surface0, fg = colors.overlay0 },
          FloatTitle = { bg = colors.surface0, fg = colors.fg },
          -- carbonfox's default DiagnosticWarn is purple (#be95ff), which
          -- reads as neither "warning" nor consistent with the standard
          -- error=red/warning=yellow/info=blue convention this theme
          -- otherwise already follows (Error #ee5396, Info #78a9ff).
          -- DiagnosticFloatingWarn/DiagnosticSignWarn link to
          -- DiagnosticWarn so overriding it covers those too;
          -- VirtualText/Underline are set independently and need their own
          -- override.
          DiagnosticWarn = { fg = '#e5c07b' },
          DiagnosticVirtualTextWarn = { fg = '#e5c07b', bg = '#322e29' },
          DiagnosticUnderlineWarn = { style = 'undercurl', sp = '#e5c07b' },
          -- Diff backgrounds, engineered against measured WCAG contrast
          -- ratios rather than eyeballed:
          --  1. Red+green is a known-bad pairing for red-green color
          --     blindness (the most common form); the accessible
          --     substitute is green+magenta or green+orange (Okabe-Ito /
          --     IBM Design Library palettes). Carbonfox's OWN sign colors
          --     already do this right (GitSignsAdd #25be6a green vs
          --     GitSignsDelete #ee5396 magenta) -- these overrides reuse
          --     those same two hues for consistency, instead of GitLab's
          --     literal red (which is objectively the worse choice here).
          --  2. A translucent whole-line wash over a near-black bg has a
          --     hard ceiling on how far add/delete can separate by
          --     contrast: blending green/magenta at equal % against
          --     #161616 (this theme's bg) caps their mutual contrast
          --     around ~1.1:1 -- indistinguishable by luminance, hue-only.
          --     GitLab's own copied colors measured the same way: 1.03:1.
          --     Pushing blend % asymmetrically (green needs less, magenta
          --     needs more, to reach equal perceived weight) is the only
          --     way to buy real separation without wrecking text
          --     legibility; these values were grid-searched for the best
          --     mutual contrast (~1.3:1) while keeping foreground text at
          --     >=4.8:1 (WCAG AA is 4.5:1) and each bg >=2.3:1 against the
          --     normal background (WCAG 1.4.11 non-text minimum is 3:1).
          --     The gutter signs remain the primary, high-contrast signal
          --     (7.5:1 / 5.4:1 against bg) -- this wash is secondary.
          DiffAdd = { bg = '#1d623c' },
          DiffDelete = { bg = '#ad4170' },
          DiffChange = { bg = '#242b37' },
          DiffTextAdd = { bg = '#246d4e' },
          DiffText = { bg = '#9d4370' },
          -- Default Visual bg is sel0 (#2a2a2a) against a #161616
          -- background -- 1.26:1 contrast, below WCAG's 3:1 floor for
          -- non-text UI, so a selection is barely distinguishable from the
          -- unselected buffer. Blending 40% toward the theme's own `white`
          -- accent (#dfdfe0) lands on #666667: 3.16:1 against the
          -- background (crosses the 3:1 floor) while keeping text sitting
          -- on top of it at 5.21:1 (above the 4.5:1 AA text minimum). One
          -- step further (50%, #7a7a7b) actually regresses text contrast
          -- to 3.89:1 even as background contrast improves, so this is the
          -- best point on the curve, not just "lighter is better".
          Visual = { bg = '#666667' },
          -- mini.cursorword defaults to linking MiniCursorword/Current to
          -- LspReferenceText, which carbonfox points at the same sel0 base
          -- as Visual's own un-overridden default (#2a2a2a, 1.26:1 against
          -- #161616 -- the exact faintness Visual was overridden for
          -- above). Cursorword can highlight many words across the visible
          -- screen at once though, not one selection, so reusing Visual's
          -- gray would read as "everything is selected" -- a distinct blue
          -- hue instead. #336b9e measures 3.22:1 against the background
          -- (clears the WCAG 3:1 non-text floor) and 5.1:1 for normal text
          -- sitting on top of it (clears the 4.5:1 AA text floor).
          MiniCursorword = { bg = '#336b9e' },
          MiniCursorwordCurrent = { bg = '#336b9e' },
          -- Default Folded bg (#252525) is 1.18:1 against #161616 -- with
          -- foldcolumn=0 (no gutter indicator, see fold.lua) this is the
          -- only visual cue a line is a closed fold, and it's nearly
          -- invisible. #5c6470 clears the WCAG 3:1 non-text floor (3.03:1)
          -- while staying distinct in hue from Visual's neutral gray
          -- (#666667) and MiniCursorword's blue (#336b9e) above -- it
          -- shouldn't read as "selected" or "cursor-matched". Default fg
          -- (#7b7c7e) was tuned for the old, darker bg and drops to 1.43:1
          -- against this one, so it's swapped for Normal's fg (5.43:1);
          -- most fold text is drawn with real treesitter colors via
          -- CustomFoldText anyway (fold.lua) -- this only covers the
          -- indentation run and the post-foldtext fill column.
          Folded = { bg = '#5c6470', fg = '#f2f4f8' },
        },
      },
    }
    vim.cmd.colorscheme 'carbonfox'
  end,
}
