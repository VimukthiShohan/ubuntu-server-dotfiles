#!/usr/bin/env bash
# skills.sh - optional AI skill frameworks. Idempotent by re-running each
# framework's official install/update command — never by presence-skip.
# DOTF_SKILLS: absent = never asked · 'none' = declined · csv = install these.
# Usage: skills.sh [--reselect]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/profile.sh
. "$SCRIPT_DIR/lib/profile.sh"
export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$HOME/.fnm:$PATH"
command -v fnm >/dev/null 2>&1 && eval "$(fnm env --shell bash)" 2>/dev/null

RESELECT=0
[[ "${1:-}" == "--reselect" ]] && RESELECT=1
FAILURES=()

# slug|label|needs-claude(0/1)
CATALOG="superclaude|SuperClaude Framework|0
superpowers|Superpowers (obra)|1
mattpocock-skills|mattpocock/skills|1
graphify|Graphify|0
react-devtools|react-devtools (Callstack; browser mode needs headed Chromium)|1
callstack-agent-skills|Callstack agent-skills (React Native)|1"

catalog_visible() {
  local line slug label needs
  while IFS='|' read -r slug label needs; do
    if [[ "$needs" == "1" ]] && ! command -v claude >/dev/null 2>&1; then
      continue
    fi
    printf '%s|%s\n' "$slug" "$label"
  done <<< "$CATALOG"
}

prompt_selection() {
  local i=1 slug label lines choice picks csv=""
  lines="$(catalog_visible)"
  {
    echo "AI skill frameworks (comma-separated numbers, empty for none):"
    while IFS='|' read -r slug label; do
      echo "  $i) $label"
      i=$((i + 1))
    done <<< "$lines"
    printf 'Pick: '
  } > /dev/tty
  IFS= read -r picks < /dev/tty || picks=""
  local total=$((i - 1))
  for choice in ${picks//,/ }; do
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > total )); then
      echo "  !! ignoring invalid selection: $choice" > /dev/tty
      continue
    fi
    slug="$(printf '%s\n' "$lines" | sed -n "${choice}p" | cut -d'|' -f1)"
    [[ ",$csv," == *",$slug,"* ]] || csv="${csv:+$csv,}$slug"
  done
  printf '%s\n' "${csv:-none}"
}

run_step() {
  local label="$1"
  shift
  echo "  -> $label"
  if "$@"; then
    return 0
  fi
  FAILURES+=("$label")
  return 0
}

install_one() {
  case "$1" in
    superclaude)
      if ! command -v pipx >/dev/null 2>&1; then
        FAILURES+=("superclaude (needs pipx — enable the python group)")
        return 0
      fi
      pipx install superclaude >/dev/null 2>&1 || run_step "superclaude: pipx upgrade" pipx upgrade superclaude
      run_step "superclaude install" superclaude install
      ;;
    superpowers)
      run_step "superpowers plugin" claude plugin install superpowers@claude-plugins-official
      ;;
    mattpocock-skills)
      run_step "mattpocock marketplace" claude plugin marketplace add mattpocock/skills
      run_step "mattpocock plugin" claude plugin install mattpocock-skills@mattpocock
      ;;
    graphify)
      if command -v uv >/dev/null 2>&1; then
        run_step "graphify: uv tool install" uv tool install graphifyy
      elif command -v pipx >/dev/null 2>&1; then
        run_step "graphify: pipx install" pipx install graphifyy
      else
        FAILURES+=("graphify (needs uv or pipx — enable the python group)")
        return 0
      fi
      command -v graphify >/dev/null 2>&1 && run_step "graphify install" graphify install
      ;;
    react-devtools)
      if ! command -v npx >/dev/null 2>&1; then
        FAILURES+=("react-devtools (needs node/npx)")
        return 0
      fi
      # No subshell around run_step — FAILURES+=() inside one would be lost.
      run_step "react-devtools skill" bash -c \
        'cd "$HOME" && npx -y skills add callstackincubator/agent-react-devtools --skill react-devtools --agent claude-code'
      ;;
    callstack-agent-skills)
      run_step "callstack marketplace" claude plugin marketplace add callstackincubator/agent-skills
      run_step "callstack react-native-best-practices" \
        claude plugin install react-native-best-practices@callstack-agent-skills
      ;;
    *)
      FAILURES+=("unknown skill slug '$1' — re-run 'dotf skills'")
      ;;
  esac
}

main() {
  local rc=0
  dotf_parse_state "$(dotf_state_file)" || rc=$?
  if (( rc == 1 )); then
    echo "!! invalid profile state — run 'dotf profile' first." >&2
    exit 1
  fi

  if (( RESELECT )) || (( ! DOTF_SKILLS_SET )); then
    # Probe /dev/tty by actually opening it (read+write). Its permission bits are
    # 0666 even with no controlling terminal, so a plain -r/-w test would look
    # interactive and then prompt a dead terminal; opening it is the only reliable
    # detection.
    if ! { : >/dev/tty && : </dev/tty; } 2>/dev/null; then
      echo "==> Non-interactive and skills never selected; skipping (a later interactive run will ask)."
      return 0
    fi
    DOTF_SKILLS="$(prompt_selection)"
    # rc==2: no state file (skills.sh run standalone) — persist under developer.
    if (( rc == 2 )); then
      dotf_write_state developer "$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" "$DOTF_SKILLS"
    else
      dotf_write_state "$DOTF_PROFILE" "$DOTF_GROUPS" "$DOTF_SKILLS"
    fi
    echo "==> Skills selection saved: $DOTF_SKILLS"
  fi

  if [[ "$DOTF_SKILLS" == "none" || -z "$DOTF_SKILLS" ]]; then
    echo "==> No AI skill frameworks selected."
    return 0
  fi

  local slug
  for slug in ${DOTF_SKILLS//,/ }; do
    echo "==> Installing skill framework: $slug"
    install_one "$slug"
  done

  echo
  if (( ${#FAILURES[@]} )); then
    echo "==> Skills completed with ${#FAILURES[@]} issue(s):"
    printf '    - %s\n' "${FAILURES[@]}"
    echo "    Re-run 'dotf skills' to retry."
    return 0
  fi
  echo "==> All selected skill frameworks installed."
}

main "$@"
