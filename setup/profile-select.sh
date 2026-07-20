#!/usr/bin/env bash
# profile-select.sh - interactive profile/group selection; writes the state
# file. The ONLY writers of the state file are this script and skills.sh.
# Usage: profile-select.sh [--if-missing]
#   --if-missing  keep an existing valid state untouched (setup.sh mode)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/profile.sh
. "$SCRIPT_DIR/lib/profile.sh"

IF_MISSING=0
[[ "${1:-}" == "--if-missing" ]] && IF_MISSING=1

old_stow_packages() {
  # Stow set of the pre-existing state (if valid) for the orphan report.
  local rc=0
  dotf_parse_state "$(dotf_state_file)" || rc=$?
  (( rc == 0 )) || return 0
  case "$DOTF_PROFILE" in
    minimal)   DOTF_ACTIVE_GROUPS="" ;;
    developer) DOTF_ACTIVE_GROUPS="$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" ;;
    custom)    DOTF_ACTIVE_GROUPS="$(dotf_closure "$DOTF_GROUPS")" ;;
  esac
  dotf_stow_packages
}

prompt_custom_groups() {
  local i choice picks csv="" idx name
  {
    echo "Groups (core is always included):"
    i=1
    for name in "${DOTF_ALL_GROUPS[@]}"; do
      echo "  $i) $name"
      i=$((i + 1))
    done
  } > /dev/tty
  while :; do
    printf 'Pick groups (comma-separated numbers, empty for none): ' > /dev/tty
    IFS= read -r picks < /dev/tty || picks=""
    csv=""
    local ok=1
    for choice in ${picks//,/ }; do
      if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#DOTF_ALL_GROUPS[@]} )); then
        echo "  !! invalid selection: $choice" > /dev/tty
        ok=0
        break
      fi
      idx=$((choice - 1))
      name="${DOTF_ALL_GROUPS[$idx]}"
      [[ ",$csv," == *",$name,"* ]] || csv="${csv:+$csv,}$name"
    done
    (( ok )) && break
  done
  printf '%s\n' "$csv"
}

main() {
  local rc=0
  dotf_parse_state "$(dotf_state_file)" || rc=$?
  if (( IF_MISSING )) && (( rc == 0 )); then
    echo "==> Profile already selected: $DOTF_PROFILE (change with 'dotf profile')"
    return 0
  fi
  (( rc == 1 )) && echo "!! existing state at $(dotf_state_file) is invalid — reselecting."

  local old_pkgs
  old_pkgs="$(old_stow_packages || true)"

  # Probe /dev/tty by actually opening it (read+write). Its permission bits are
  # 0666 even with no controlling terminal, so a plain -r/-w test would look
  # interactive and then crash on the first prompt under set -e; opening it is the
  # only reliable detection.
  if ! { : >/dev/tty && : </dev/tty; } 2>/dev/null; then
    echo "==> Non-interactive: defaulting to the 'developer' profile."
    dotf_write_state developer "$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")"
    return 0
  fi

  local choice profile groups=""
  while :; do
    {
      echo "Select a profile:"
      echo "  1) minimal    — server essentials only"
      echo "  2) developer  — everything (editor stack, runtimes, AI CLIs)"
      echo "  3) custom     — essentials + groups you pick"
      printf 'Choice [1-3]: '
    } > /dev/tty
    IFS= read -r choice < /dev/tty || choice=""
    case "$choice" in
      1) profile=minimal;   groups="" ;;
      2) profile=developer; groups="$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" ;;
      3) profile=custom;    groups="$(prompt_custom_groups)" ;;
      *) echo "  !! pick 1, 2, or 3" > /dev/tty; continue ;;
    esac
    break
  done

  if [[ "$profile" == "custom" && -n "$groups" ]]; then
    # Compare against the SORTED picks so pure reordering never reads as
    # "dependencies added".
    local closed picked_sorted
    closed="$(dotf_closure "$groups")"
    # shellcheck disable=SC2086
    picked_sorted="$(printf '%s\n' ${groups//,/ } | sort | paste -sd, -)"
    if [[ "$closed" != "$picked_sorted" ]]; then
      echo "==> Added dependency groups: closure is '$closed' (you picked '$groups')."
    fi
    groups="$closed"
  fi

  dotf_write_state "$profile" "$groups"
  echo "==> Profile '$profile' saved to $(dotf_state_file)"

  # Orphan report: stow packages the new selection no longer covers.
  if [[ -n "$old_pkgs" ]]; then
    case "$profile" in
      minimal)   DOTF_ACTIVE_GROUPS="" ;;
      developer) DOTF_ACTIVE_GROUPS="$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" ;;
      custom)    DOTF_ACTIVE_GROUPS="$(dotf_closure "$groups")" ;;
    esac
    local new_pkgs pkg orphan=0
    new_pkgs="$(dotf_stow_packages)"
    for pkg in $old_pkgs; do
      if ! printf '%s\n' "$new_pkgs" | grep -qx "$pkg"; then
        (( orphan )) || echo "==> No-longer-active stow packages (not removed automatically):"
        orphan=1
        echo "    $pkg — remove with: cd \"\$HOME/.dotfiles\" && stow -D $pkg"
      fi
    done
    (( orphan )) && echo "    Installed tools from removed groups also remain; uninstall manually if unwanted."
  fi
  return 0
}

main "$@"
