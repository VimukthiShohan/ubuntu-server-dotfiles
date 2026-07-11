# Completion paths and cache-aware initialization.
[[ -d "$HOME/.zsh/completions" ]] && fpath=("$HOME/.zsh/completions" $fpath)
[[ -d "$HOME/.zsh/zsh-completions/src" ]] && fpath=("$HOME/.zsh/zsh-completions/src" $fpath)

autoload -Uz compinit add-zsh-hook vcs_info is-at-least

_zcompdump_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
_zcompdump="$_zcompdump_dir/zcompdump-$ZSH_VERSION"

[[ -d "$_zcompdump_dir" ]] || command mkdir -p "$_zcompdump_dir"

if [[ -r "$_zcompdump" ]]; then
  compinit -C -d "$_zcompdump"
else
  compinit -d "$_zcompdump"
fi

unset _zcompdump _zcompdump_dir

# bun completions
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
