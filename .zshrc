# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME=""

# Completion caching for faster startup
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"

# Faster completion
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-ip true
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
zstyle ':completion:*:warnings' format '%BSorry, no matches for: %d%b'

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git fzf fzf-tab zoxide)

source $ZSH/oh-my-zsh.sh
eval "$(starship init zsh)"
# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias by="bundle && yarn"
alias watch="watch -c"
alias kx=kubectx
alias kns=kubens
alias ds="dig +short "
alias watchh="watch "
alias rgi="rg -i"
alias oc=opencode

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fpath+=("$(brew --prefix)/share/zsh/site-functions") 
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f ~/.kubectl_aliases ] && source \
   <(cat ~/.kubectl_aliases | sed -r 's/(kubectl.*) --watch/watch \1/g')

# Added by GDK bootstrap
eval "$(/opt/homebrew/bin/mise activate zsh)"

# Custom function that clones the remote repository according
# to the location of the remote repository.
# gitlab.com/gitlab-org/gitlab will be cloned to 
# /Users/ashvin/workspace/gitlab-org/gitlab
git-import() {
    repo_url=$1
    repo_path="$HOME/workspace/$(echo "$repo_url" | sed -E 's|git@[^:]+:||; s|https://[^/]+/||; s|\.git$||')"
    git clone "$repo_url" "$repo_path" && cd "$repo_path"
}

export DEVELOPER_DIR="$(xcode-select -p)"
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/ashvin/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
export GDK_ROOT="/Users/ashvin/workspace/gitlab-org/gdk"

# Added by Windsurf
export PATH="/Users/ashvin/.codeium/windsurf/bin:$PATH"
alias ws="windsurf"

# Better history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY

# Modern tool aliases
alias ls="eza --icons"
alias ll="eza -la --icons --git"
alias tree="eza --tree --icons"
alias c="claude"

# FZF configuration (uses fd for file finding, rg for content)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# Use bat for fzf preview
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :500 {}'"

# Added by GitLab Knowledge Graph installer
export PATH="$HOME/.local/bin:$PATH"

export OLLAMA_NUM_PARALLEL=4 
export OLLAMA_MAX_LOADED_MODELS=3
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_KV_CACHE_TYPE="q8_0"
export OLLAMA_CONTEXT_LENGTH=8192

# bun completions
[ -s "/Users/ashvin/.bun/_bun" ] && source "/Users/ashvin/.bun/_bun"


# Rename tmux window on directory change
chpwd() { [[ -n "$TMUX" ]] && ~/.config/tmux/smart-rename.sh "$PWD" }

# glab account switcher — personal vs work based on git remote
glab() {
  local remote
  remote="$(git remote get-url origin 2>/dev/null)" || true

  if [[ "$remote" == git@gitlab-personal:* ]]; then
    GITLAB_TOKEN="$(security find-generic-password -a "$(whoami)" -s "opencode_gitlab_mcp_pat_key" -w 2>/dev/null)" \
      command glab "$@"
  else
    command glab "$@"
  fi
}

# Disable Ctrl+S flow control (XOFF) so it can be used as tmux prefix
stty -ixon 2>/dev/null
# test

loadenv() {
    [[ -f "$1" ]] || { echo "file $1 not found"; return 1; }
    set -a
    source "$1"
    set +a
}
