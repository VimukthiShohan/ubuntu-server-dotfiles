# tmx — Personal tmux dev workspace bootstrapper

A self-contained package that creates a tmux session with a project-aware window
layout. Invoked via the `tmx` alias from any project directory.

## File structure

```
scripts/tmx/
├── main.sh              # Entry point: session management, port allocation, orchestration
├── lib/
│   ├── harness.sh       # AI harness resolution: validation, config, interactive prompt
│   ├── windows.sh       # Window creation functions (one per window type)
│   └── detect-serve.sh  # Dev server command detection (justfile/package.json/Makefile)
├── config/
│   └── harnesses.conf   # Declarative harness registry (name|command)
└── README.md            # This file
```

## Windows created

| # | Name       | Always? | What runs                                      |
|---|------------|---------|------------------------------------------------|
| 1 | `ai`       | ✓       | 1–3 AI harness panes (opencode, claude, codex) |
| 2 | `vim`      | ✓       | Neovim (via `vim` alias) with `OPENCODE_PORT`  |
| 3 | `terminal` | ✓       | Plain zsh shell                                |
| 4 | `git`      | ✗       | Lazygit — only in git repos                    |
| 5 | `serve`    | ✗       | Dev server — only when detection succeeds and not skipped |

## AI harness resolution

Harnesses are resolved in priority order:

1. **CLI args** — `tmx opencode claude`
2. **Project config** — `.ai-harnesses.json` in the project root (`["opencode", "claude"]`)
3. **Interactive prompt** — `gum` TUI chooser (asks count, then per-pane selection)

## How to extend

### Add a new AI harness

Edit `config/harnesses.conf` — add one line:

```
aider|aider --model gpt-4
```

That's it. The allow-list, validation, interactive prompt, and command mapping all
derive from this file automatically.

### Add a new window

1. Add a function to `lib/windows.sh`:

```zsh
create_docker_window() {
  tmux new-window -t "$SESSION" -n "docker" -c "$PWD"
  tmux send-keys -t "$SESSION:6" "lazydocker" C-m
}
```

2. Call it from `main.sh` (after the existing `create_*` calls):

```zsh
create_docker_window
```

### Add a new serve detector

Edit the `detect_serve_command()` function in `lib/detect-serve.sh`. Add an
`elif` clause following the existing pattern (justfile → package.json → Makefile).

## Usage

```bash
# Explicit harnesses
tmx opencode claude codex   # 3-pane AI window
tmx claude                  # single full-pane AI window

# Skip serve detection/window
tmx --no-serve opencode
tmx -ns opencode claude

# Project config (reads .ai-harnesses.json)
tmx

# Interactive (no args, no config file)
tmx
```

If a session already exists for the directory, `tmx` attaches to it without
recreating.

## Notes for coding agents

- This is a personal script, not a portable tool. Do not generalize unless asked.
- `vim`, `lg` are shell aliases defined in `.zshrc` (`nvim`, `lazygit`).
- `tmux`, `jq`, `gum`, `lazygit` are expected via this dotfiles setup.
- If the session already exists, the script attaches and does not reconcile layout.
- If `serve` is missing, detection did not match — this is expected, not a bug.
- Use `--no-serve` or `-ns` to skip serve detection and avoid creating the
  `serve` window.
- If `jq` is missing in a Node project, that's a local env issue, not a reason
  to add a fallback.
