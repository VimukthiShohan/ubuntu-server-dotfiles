#!/usr/bin/env zsh

# === Instructions for coding agents ===
# Personal tmux workspace bootstrapper. See README.md in this directory for
# full documentation, extension guides, and design rationale.
# Run via `tmx` alias (defined in .zshrc). Invoked from a project directory.

set -euo pipefail

TMX_DIR="${0:A:h}"
SESSION="$(basename "$PWD" | sed 's/^\.//')"

# Source library modules
source "$TMX_DIR/lib/harness.sh"
source "$TMX_DIR/lib/detect-serve.sh"
source "$TMX_DIR/lib/windows.sh"

# Load harness registry (populates ALLOWED_HARNESSES + HARNESS_COMMANDS)
load_harness_registry

# Set Ghostty tab title to session name
printf '\e]2;%s\a' "$SESSION"

# Fail fast if tmux isn't available
if ! command -v tmux &>/dev/null; then
  echo "tmux not found" >&2
  exit 1
fi

# Attach to existing session instead of recreating
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Session '$SESSION' already exists. Attaching..."
  exec tmux attach-session -t "$SESSION"
fi

# --- Create new session ---

tmux new-session -d -s "$SESSION" -c "$PWD"

# Pick a random free port between 65000 and 65500 for OpenCode
while true; do
  PORT=$((RANDOM % 501 + 65000))
  if command -v lsof &>/dev/null; then
    lsof -Pi :"$PORT" -sTCP:LISTEN &>/dev/null || break
  elif command -v nc &>/dev/null; then
    nc -z localhost "$PORT" &>/dev/null || break
  else
    break
  fi
done
tmux set-environment -t "$SESSION" OPENCODE_PORT "$PORT"

# Split tmx options from harness arguments before validation.
NO_SERVE=0
HARNESS_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --no-serve|-ns)
      NO_SERVE=1
      ;;
    *)
      HARNESS_ARGS+=("$arg")
      ;;
  esac
done

# Resolve AI harnesses and create all windows
AI_HARNESSES=($(resolve_harnesses "${HARNESS_ARGS[@]}"))

create_ai_window "${AI_HARNESSES[@]}"
create_vim_window
create_terminal_window
create_git_window
if (( ! NO_SERVE )); then
  create_serve_window
fi

# Focus window 1 and attach
tmux select-window -t "$SESSION:1"
exec tmux attach-session -t "$SESSION"
