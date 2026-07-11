# Core environment and path setup.
typeset -U path PATH fpath FPATH

export HISTFILE="$HOME/.histfile"
export HISTSIZE=1000
export SAVEHIST=1000

export EDITOR=nvim
export BAT_THEME=Dracula
export EZA_CONFIG_DIR="$HOME/.config/eza"
export ENABLE_LSP_TOOL=1
export FNM_LOGLEVEL=quiet

export BUN_INSTALL="$HOME/.bun"
export PNPM_HOME="$HOME/.local/share/pnpm"
export ANDROID_HOME="$HOME/Android/Sdk"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

path=(
  "$HOME/.local/bin"
  "$HOME/.local/share/fnm"
  "$HOME/.fnm"
  "$HOME/.opencode/bin"
  "$HOME/.maestro/bin"
  "$HOME/go/bin"
  "$BUN_INSTALL/bin"
  "$PNPM_HOME"
  "$HOME/Developer/Flutter/flutter/bin"
  "$HOME/.pub-cache/bin"
  $path
)
