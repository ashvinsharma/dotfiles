# Homebrew dependencies required for this dotfiles repo's nvim config to
# work on a fresh machine. Curated by hand (not a full `brew bundle dump`)
# -- everything here is tied to a specific config file below. Runtime/CLI
# tool *versions* (go, node, ruby, tree-sitter, gotestsum, etc.) are handled
# by mise instead (see .config/mise/config.toml + `make bootstrap`).
#
# `xcode-select --install` (a C compiler) is also required -- for building
# treesitter parsers and any luarocks native deps -- but isn't a brew
# formula, so it isn't listed here.

# rest.nvim (.config/nvim/lua/custom/plugins/rest.lua): luarocks needs a
# Lua 5.1-compatible interpreter to satisfy its rockspec deps' version gate.
# LuaJIT reports itself as Lua 5.1, which is what Neovim itself embeds.
brew "luajit"
brew "luarocks"

# telescope.lua / fzf-lua.lua: live-grep, find_files, and the fzf-lua
# picker all shell out to these real binaries instead of reimplementing
# them in Lua.
brew "ripgrep" # `rg`, live-grep
brew "fd" # find_files
brew "fzf" # fzf-lua's actual backend
brew "git-delta" # `delta`, diff preview pane in telescope.lua

# gitsigns.lua: kdheepak/lazygit.nvim's :LazyGit command shells out to the
# real lazygit binary.
brew "lazygit"

# neo-tree.lua / bufferline / starship.toml: icons and prompt glyphs render
# as broken boxes without a Nerd Font. Also set as ghostty's font-family.
cask "font-jetbrains-mono-nerd-font"
