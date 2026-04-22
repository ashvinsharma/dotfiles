
eval "$(/opt/homebrew/bin/brew shellenv)"


# Added by Toolbox App
export PATH="$PATH:/Users/ashvin/Library/Application Support/JetBrains/Toolbox/scripts"


# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

export PATH="$HOME/.local/share/mise/shims:$PATH"
eval "$(mise activate zsh --shims)"

# Added by GitLab Knowledge Graph installer
export PATH="$HOME/.local/bin:$PATH"
