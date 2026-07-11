# Language runtimes and interactive shell helpers.
[[ -f "$HOME/.deno/env" ]] && source "$HOME/.deno/env"
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
[[ -f "$HOME/.dart-cli-completion/zsh-config.zsh" ]] && source "$HOME/.dart-cli-completion/zsh-config.zsh"
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - zsh)"
fi

if command -v yazi >/dev/null 2>&1; then
  y() {
    local tmp cwd
    tmp="$(mktemp -t 'yazi-cwd.XXXXXX')" || return
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(<"$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

fk() {
  unfunction fk
  if ! command -v thefuck >/dev/null 2>&1; then
    print -u2 'fk: thefuck is not installed'
    return 127
  fi

  eval "$(thefuck --alias fk)"
  fk "$@"
}
