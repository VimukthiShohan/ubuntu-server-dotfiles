# Editor aliases.
alias vim='nvim'
alias vimdiff='nvim -d'

# Navigation and listing replacements.
alias lsu='du -sh ./* | sort -hr | head -n 10'
alias ls='eza'
alias ll='eza -alh'
alias tree='eza --tree'
alias cat='bat'

# Project and terminal tools.
alias cdx='cd && clear'
alias lg='lazygit'
alias tmx="$HOME/.dotfiles/scripts/tmx/main.sh"
alias tmk='tmux kill-session'
alias snv="$HOME/.dotfiles/scripts/switch_nvim_config.sh"

# Package manager shortcuts.
alias px='pnpm dlx'
alias pr='pnpm run'
alias pin='pnpm install'
alias pab='pnpm approve-builds'

# AI tools.
alias cc='claude'
alias oc='opencode'

# Docker Compose.
alias dcu='docker compose up -d'
alias dcua='docker compose up'
alias dcd='docker compose down'
alias dsp='docker system prune'

# dotfiles apply script.
alias nb='cd "$HOME/.dotfiles" && ./apply.sh && cd'
