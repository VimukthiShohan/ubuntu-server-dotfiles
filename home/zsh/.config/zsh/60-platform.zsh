# Platform-specific paths and aliases.
if command -v xclip >/dev/null 2>&1; then
  alias copy='xclip -selection clipboard'
elif command -v wl-copy >/dev/null 2>&1; then
  alias copy='wl-copy'
fi

if [[ -d "$ANDROID_HOME" ]]; then
  [[ -d "$ANDROID_HOME/emulator" ]] && path+=("$ANDROID_HOME/emulator")
  [[ -d "$ANDROID_HOME/platform-tools" ]] && path+=("$ANDROID_HOME/platform-tools")
  [[ -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]] && path+=("$ANDROID_HOME/cmdline-tools/latest/bin")
fi
