# Optional machine-local overrides. Keep secrets out of the repo.
_zsh_local_config="$ZSH_CONFIG_DIR/local.zsh"
[[ -r "$_zsh_local_config" ]] && source "$_zsh_local_config"
unset _zsh_local_config
