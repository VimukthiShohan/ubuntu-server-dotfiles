# Powerlevel10k instant prompt must stay near the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_CONFIG_DIR="${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}"

_zsh_modules=(
  00-env.zsh
  10-completion.zsh
  20-prompt.zsh
  30-aliases.zsh
  40-fzf.zsh
  50-tools.zsh
  60-platform.zsh
  90-local.zsh
)

for _zsh_module in "${_zsh_modules[@]}"; do
  [[ -r "$ZSH_CONFIG_DIR/$_zsh_module" ]] && source "$ZSH_CONFIG_DIR/$_zsh_module"
done

unset _zsh_module _zsh_modules

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
