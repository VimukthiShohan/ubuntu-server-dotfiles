#!/usr/bin/env bash
# setup/lib/profile.sh - single source of truth for profiles, groups, and the
# state file. Sourced by setup.sh, apply.sh, doctor.sh, install-tools.sh,
# tools/installers.sh, profile-select.sh, skills.sh, and the tests.
# Spec: docs/superpowers/specs/2026-07-20-bootstrap-profiles-design.md
# Must run under bash 3.2 (macOS dev machines run the guard test).
# No side effects at source time; state file is parsed, never sourced.

DOTF_ALL_GROUPS=(ergonomics build services nvim node rust go-tools python ai-clis cloud media)

dotf_state_file() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/dotf/profile"
}

dotf_known_group() {
  local g
  for g in "${DOTF_ALL_GROUPS[@]}"; do
    [[ "$g" == "$1" ]] && return 0
  done
  return 1
}

dotf_group_deps() {
  case "$1" in
    nvim)    echo "build node" ;;
    rust)    echo "build" ;;
    ai-clis) echo "node" ;;
  esac
}

# One-line "what this installs" summary per group, shown in the custom picker.
# Keep in sync with the group table in README.md.
dotf_group_summary() {
  case "$1" in
    ergonomics) echo "ripgrep, fd, fzf, bat, eza, delta, zoxide, btop, direnv, just, thefuck, shellcheck, gh" ;;
    build)      echo "build-essential, cmake, ninja, pkg-config" ;;
    services)   echo "Docker, docker-compose, postgres/redis CLI clients" ;;
    nvim)       echo "Neovim, lua-language-server, tree-sitter-cli" ;;
    node)       echo "fnm/Node, bun, pnpm" ;;
    rust)       echo "rustup, yazi, rtk" ;;
    go-tools)   echo "Go toolchain, gum, lazygit" ;;
    python)     echo "pip/venv, pipx, uv" ;;
    ai-clis)    echo "claude, opencode, codex" ;;
    cloud)      echo "AWS CLI v2" ;;
    media)      echo "imagemagick, poppler-utils" ;;
  esac
}

dotf_group_stow_packages() {
  case "$1" in
    core)       echo "zsh git tmux dotf" ;;
    ergonomics) echo "eza btop neofetch gh git-dev" ;;
    nvim)       echo "nvim nvim-nightly" ;;
    go-tools)   echo "lazygit" ;;
  esac
}

# csv in -> sorted deduped csv out, dependencies included. Recomputed on every
# load so registry changes migrate existing machines automatically.
dotf_closure() {
  local queue seen="" g d
  queue="${1//,/ }"
  while [[ -n "${queue// /}" ]]; do
    g="${queue%% *}"
    if [[ "$queue" == *" "* ]]; then queue="${queue#* }"; else queue=""; fi
    [[ -n "$g" ]] || continue
    case " $seen " in *" $g "*) continue ;; esac
    seen="$seen $g"
    for d in $(dotf_group_deps "$g"); do
      queue="$queue $d"
    done
  done
  [[ -n "${seen// /}" ]] || return 0
  # shellcheck disable=SC2086
  printf '%s\n' $seen | sort | paste -sd, -
}

# Sets DOTF_PROFILE, DOTF_GROUPS, DOTF_SKILLS, DOTF_SKILLS_SET.
# Returns 0 ok / 2 missing / 1 invalid (reason on stderr).
dotf_parse_state() {
  local file="$1" line key val seen_keys="," g
  DOTF_PROFILE="" DOTF_GROUPS="" DOTF_SKILLS="" DOTF_SKILLS_SET=0
  [[ -f "$file" ]] || return 2
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if [[ ! "$line" =~ ^(DOTF_PROFILE|DOTF_GROUPS|DOTF_SKILLS)=([a-z0-9@,._/-]*)$ ]]; then
      echo "!! invalid line in $file: $line" >&2
      return 1
    fi
    key="${BASH_REMATCH[1]}" val="${BASH_REMATCH[2]}"
    if [[ "$seen_keys" == *",$key,"* ]]; then
      echo "!! duplicate key $key in $file" >&2
      return 1
    fi
    seen_keys="$seen_keys$key,"
    case "$key" in
      DOTF_PROFILE) DOTF_PROFILE="$val" ;;
      DOTF_GROUPS)  DOTF_GROUPS="$val" ;;
      DOTF_SKILLS)  DOTF_SKILLS="$val"; DOTF_SKILLS_SET=1 ;;
    esac
  done < "$file"
  case "$DOTF_PROFILE" in
    minimal|developer|custom) ;;
    *) echo "!! invalid DOTF_PROFILE '$DOTF_PROFILE' in $file" >&2; return 1 ;;
  esac
  if [[ -n "$DOTF_GROUPS" ]]; then
    for g in ${DOTF_GROUPS//,/ }; do
      if ! dotf_known_group "$g"; then
        echo "!! unknown group '$g' in $file" >&2
        return 1
      fi
    done
  fi
  return 0
}

# Read-only load policy: missing -> developer fallback with a warning;
# invalid -> hard error pointing at 'dotf profile'. Sets DOTF_ACTIVE_GROUPS.
dotf_load_state_ro() {
  local file rc=0
  file="$(dotf_state_file)"
  dotf_parse_state "$file" || rc=$?
  if (( rc == 2 )); then
    echo "!! no profile state at $file — assuming 'developer' (run 'dotf profile' to choose)." >&2
    DOTF_PROFILE=developer
  elif (( rc == 1 )); then
    echo "!! invalid profile state at $file — run 'dotf profile' to repair it." >&2
    exit 1
  fi
  case "$DOTF_PROFILE" in
    minimal)   DOTF_ACTIVE_GROUPS="" ;;
    developer) DOTF_ACTIVE_GROUPS="$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" ;;
    custom)    DOTF_ACTIVE_GROUPS="$(dotf_closure "$DOTF_GROUPS")" ;;
  esac
}

dotf_group_active() {
  [[ "$1" == "core" ]] && return 0
  [[ ",${DOTF_ACTIVE_GROUPS:-}," == *",$1,"* ]]
}

# Atomic write. Third arg omitted -> preserve an existing DOTF_SKILLS line.
dotf_write_state() {
  local profile="$1" groups="$2" skills="${3-__preserve__}" file dir tmp rc=0
  file="$(dotf_state_file)"
  dir="$(dirname "$file")"
  mkdir -p "$dir"
  if [[ "$skills" == "__preserve__" ]]; then
    skills=""
    dotf_parse_state "$file" || rc=$?
    if (( rc == 0 )) && (( DOTF_SKILLS_SET )); then
      skills="$DOTF_SKILLS"
    fi
  fi
  tmp="$(mktemp "$dir/.profile-write.XXXXXX")"
  {
    echo "DOTF_PROFILE=$profile"
    echo "DOTF_GROUPS=$groups"
    [[ -n "$skills" ]] && echo "DOTF_SKILLS=$skills"
  } > "$tmp"
  mv "$tmp" "$file"
}

# Shared manifest walker. $2 = 1 -> also emit active-group package lines.
_dotf_walk_manifest() {
  local file="$1" emit="$2" line group=""
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^##\ group:\ ([a-z-]+)$ ]]; then
      group="${BASH_REMATCH[1]}"
      if [[ "$group" != "core" ]] && ! dotf_known_group "$group"; then
        echo "!! $file: unknown group header '$group'" >&2
        return 1
      fi
      continue
    fi
    # A header-looking line that failed the strict regex must be an error, not
    # a silently-skipped comment (its packages would inherit the wrong group).
    if [[ "$line" == '## group:'* ]]; then
      echo "!! $file: malformed group header: $line" >&2
      return 1
    fi
    case "$line" in ''|\#*|[[:space:]]*\#*) continue ;; esac
    [[ -z "${line// /}" ]] && continue
    if [[ -z "$group" ]]; then
      echo "!! $file: package line before any '## group:' header: $line" >&2
      return 1
    fi
    if (( emit )) && dotf_group_active "$group"; then
      printf '%s\n' "$line"
    fi
  done < "$file"
}

dotf_filter_manifest()   { _dotf_walk_manifest "$1" 1; }
dotf_validate_manifest() { _dotf_walk_manifest "$1" 0; }

# Stow packages for the active groups, one per line, core first.
dotf_stow_packages() {
  local g p
  for g in core "${DOTF_ALL_GROUPS[@]}"; do
    dotf_group_active "$g" || continue
    for p in $(dotf_group_stow_packages "$g"); do
      printf '%s\n' "$p"
    done
  done
}
