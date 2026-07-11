# lib/windows.sh — Window creation functions for tmux dev setup
# Sourced by main.sh. Expects: SESSION, PORT (set by main.sh)
# Also uses: get_harness_command (from lib/harness.sh)
#            detect_serve_command (from lib/detect-serve.sh)

# Window 1: ai — dynamic harness pane layout
# Creates panes first, then sends commands to avoid race conditions.
# Layouts:
#   1 pane:  full window
#   2 panes: vertical split (left | right)
#   3 panes: main-vertical (left | top-right / bottom-right)
create_ai_window() {
  local -a harnesses=("$@")
  local harness_count=${#harnesses[@]}

  tmux rename-window -t "$SESSION:1" "ai"

  if [[ $harness_count -ge 2 ]]; then
    tmux split-window -h -t "$SESSION:1"
  fi
  if [[ $harness_count -eq 3 ]]; then
    tmux split-window -v -t "$SESSION:1.2"
  fi

  for ((i=1; i<=harness_count; i++)); do
    local harness="${harnesses[$i]}"
    local cmd
    cmd=$(get_harness_command "$harness")
    tmux send-keys -t "$SESSION:1.$i" "$cmd" C-m
  done

  tmux select-pane -t "$SESSION:1.1"
}

# Window 2: vim (nvim with OPENCODE_PORT)
create_vim_window() {
  tmux new-window -t "$SESSION" -n "vim" -c "$PWD"
  tmux send-keys -t "$SESSION:2" "OPENCODE_PORT=$PORT vim" C-m
}

# Window 3: terminal (plain zsh)
create_terminal_window() {
  tmux new-window -t "$SESSION" -n "terminal" -c "$PWD"
}

# Window 4: git (lazygit — only created inside git repos)
create_git_window() {
  if git rev-parse --git-dir &>/dev/null; then
    tmux new-window -t "$SESSION" -n "git" -c "$PWD"
    tmux send-keys -t "$SESSION:4" "lg" C-m
  fi
}

# Window 5: serve (dev server — only created when detection succeeds)
create_serve_window() {
  local serve_cmd
  serve_cmd=$(detect_serve_command)

  if [[ -n "$serve_cmd" ]]; then
    tmux new-window -t "$SESSION" -n "serve" -c "$PWD"
    tmux send-keys -t "$SESSION:5" "$serve_cmd" C-m
  fi
}
