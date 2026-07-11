# Platform-specific paths and aliases.
if command -v xclip >/dev/null 2>&1; then
  alias copy='xclip -selection clipboard'
elif command -v wl-copy >/dev/null 2>&1; then
  alias copy='wl-copy'
fi
