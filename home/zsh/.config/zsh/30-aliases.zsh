# Editor aliases (guarded: minimal profile ships no nvim).
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
  alias vimdiff='nvim -d'
fi

# Navigation and listing replacements (guarded: ergonomics group optional).
alias lsu='du -sh ./* | sort -hr | head -n 10'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza'
  alias ll='eza -alh'
  alias tree='eza --tree'
fi
command -v bat >/dev/null 2>&1 && alias cat='bat'

# Project and terminal tools.
alias cdx='cd && clear'
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'
alias tmx="$HOME/.dotfiles/scripts/tmx/main.sh"
alias tmk='tmux kill-session'
alias snv="$HOME/.dotfiles/scripts/switch_nvim_config.sh"

# Package manager shortcuts.
alias px='pnpm dlx'
alias pr='pnpm run'
alias pin='pnpm install'
alias pab='pnpm approve-builds'

# AI tools.
command -v claude >/dev/null 2>&1 && alias cc='claude'
command -v opencode >/dev/null 2>&1 && alias oc='opencode'

# Docker Compose.
alias dcu='docker compose up -d'
alias dcua='docker compose up'
alias dcd='docker compose down'
alias dsp='docker system prune'

# dotfiles apply script.
alias nb='cd "$HOME/.dotfiles" && ./apply.sh && cd'
