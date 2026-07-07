-- [[ Reload Ghostty's config whenever its config file is saved ]]
-- Ghostty has no CLI/IPC to reload a running instance -- only the
-- `reload_config` keybind (default `super+shift+,`, see
-- ~/.config/ghostty/config) or the app menu can trigger it, and Ghostty
-- itself documents that `+edit-config` "will not reload the configuration
-- after editing". So this synthesizes that keypress via AppleScript,
-- relying on Ghostty being the frontmost app while you're editing its
-- config in it. Requires Ghostty to have Accessibility permission
-- (System Settings -> Privacy & Security -> Accessibility) for the
-- synthetic keystroke to be delivered.

vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = '*/ghostty/config',
  callback = function()
    vim.fn.jobstart({
      'osascript',
      '-e',
      'tell application "System Events" to keystroke "," using {command down, shift down}',
    }, { detach = true })
  end,
})
