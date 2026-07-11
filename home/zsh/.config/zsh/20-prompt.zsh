# Powerlevel10k prompt loading. Installation belongs in setup scripts, not shell startup.
_p10k_theme=

[[ -r "$HOME/powerlevel10k/powerlevel10k.zsh-theme" ]] && \
  _p10k_theme="$HOME/powerlevel10k/powerlevel10k.zsh-theme"

[[ -n "$_p10k_theme" ]] && source "$_p10k_theme"

unset _p10k_theme
