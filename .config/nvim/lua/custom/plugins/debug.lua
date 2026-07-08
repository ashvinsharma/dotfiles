return {
  'mfussenegger/nvim-dap',
  dependencies = {
    -- UI: breakpoints, scopes/variables, call stack, watches, REPL/console
    -- -- IntelliJ's debug tool window, roughly.
    {
      'rcarriga/nvim-dap-ui',
      dependencies = { 'nvim-neotest/nvim-nio' },
    },
    -- Inline variable values next to the cursor while stepping, instead of
    -- only in the UI's scopes panel.
    'theHamsta/nvim-dap-virtual-text',
    -- Go adapter -- uses the `dlv` binary, already installed via Mason and
    -- on PATH (mason.nvim prepends its bin dir), no extra config needed.
    'leoluz/nvim-dap-go',
    -- Ruby adapter -- needs the `readapt` gem installed under whichever
    -- Ruby mise has active for the project (`gem install readapt`, or add
    -- it to the project's Gemfile). Mason can't install this one itself,
    -- same situation as ruby_lsp/rubocop in nvim-lspconfig.lua.
    'suketa/nvim-dap-ruby',
  },
  keys = {
    -- IntelliJ's own debug keymap. <F1> is already the custom hover system
    -- (nvim-lspconfig.lua) so it's off-limits here.
    {
      '<F9>',
      function()
        require('dap').continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F8>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F7>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<S-F8>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>Db',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = '[D]ebug [B]reakpoint toggle',
    },
    {
      '<leader>DB',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = '[D]ebug [B]reakpoint (conditional)',
    },
    {
      '<leader>Dr',
      function()
        require('dap').repl.toggle()
      end,
      desc = '[D]ebug [R]EPL',
    },
    {
      '<leader>Dl',
      function()
        require('dap').run_last()
      end,
      desc = '[D]ebug run [L]ast',
    },
    {
      '<leader>Dt',
      function()
        require('dap').terminate()
      end,
      desc = '[D]ebug [T]erminate',
    },
    {
      '<leader>Du',
      function()
        require('dapui').toggle()
      end,
      desc = '[D]ebug [U]I toggle',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    dapui.setup()
    require('nvim-dap-virtual-text').setup()
    require('dap-go').setup()
    require('dap-ruby').setup()

    -- Auto open/close the UI around a debug session, mirroring IntelliJ's
    -- debug tool window appearing the moment you hit a breakpoint.
    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Breakpoint/stopped-line signs, reusing the same severity highlight
    -- groups as LSP diagnostics (nvim-lspconfig.lua) for a consistent look.
    vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DiagnosticError', linehl = '', numhl = '' })
    vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'DiagnosticError', linehl = '', numhl = '' })
    vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DiagnosticWarn', linehl = 'CursorLine', numhl = '' })
  end,
}
