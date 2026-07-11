#!/usr/bin/env bash
# doctor.sh - read-only drift/status checks for the Ubuntu dotfiles branch.

set -u

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APT_PACKAGES="$DOTFILES/setup/apt-packages.txt"
ISSUES=0

warn()    { echo "  !! $*"; ISSUES=$((ISSUES + 1)); }
ok()      { echo "  ok $*"; }
section() { echo; echo "==> $*"; }

read_manifest() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$file" || true
}

main() {
  section "Checking platform"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" == "ubuntu" ]]; then
      ok "${PRETTY_NAME:-Ubuntu}"
    else
      warn "Expected Ubuntu, detected ${PRETTY_NAME:-unknown}"
    fi
  else
    warn "/etc/os-release not found"
  fi

  section "Checking required commands"
  for cmd in sudo apt-get git stow zsh tmux nvim curl; do
    if command -v "$cmd" >/dev/null 2>&1; then
      ok "$cmd ($(command -v "$cmd"))"
    else
      warn "$cmd not found"
    fi
  done

  section "Checking apt package declarations"
  if [[ ! -f "$APT_PACKAGES" ]]; then
    warn "apt package manifest missing at $APT_PACKAGES"
  else
    local package
    while IFS= read -r package; do
      [[ -n "$package" ]] || continue
      if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        ok "$package"
      else
        warn "$package missing - run apply.sh"
      fi
    done < <(read_manifest "$APT_PACKAGES")
  fi

  section "Checking post-install repos"
  [[ -d "$HOME/.fzf-git.sh" ]] && ok "~/.fzf-git.sh present" || warn "~/.fzf-git.sh missing"
  [[ -d "$HOME/.tmux/plugins/tpm" ]] && ok "~/.tmux/plugins/tpm present" || warn "~/.tmux/plugins/tpm missing"
  [[ -d "$HOME/powerlevel10k" ]] && ok "~/powerlevel10k present" || warn "~/powerlevel10k missing"

  section "Stow dry-run"
  if ! command -v stow >/dev/null 2>&1; then
    warn "stow not found"
  else
    local packages=()
    local package_path
    while IFS= read -r package_path; do
      packages+=("$(basename "$package_path")")
    done < <(find "$DOTFILES/home" -mindepth 1 -maxdepth 1 -type d | sort)

    if (( ${#packages[@]} == 0 )); then
      warn "No stow packages found under $DOTFILES/home"
    else
      local stow_out
      stow_out="$(stow -d "$DOTFILES/home" -t "$HOME" --no --verbose "${packages[@]}" 2>&1 || true)"
      if echo "$stow_out" | grep -qiE 'CONFLICT|existing target|cannot stow'; then
        warn "Stow conflicts detected:"
        echo "$stow_out" | grep -iE 'CONFLICT|existing target|cannot stow' | sed 's/^/    /'
      else
        ok "No stow conflicts"
      fi
    fi
  fi

  section "Repo git status"
  local dirty
  dirty="$(git -C "$DOTFILES" status --short)"
  if [[ -n "$dirty" ]]; then
    echo "$dirty" | sed 's/^/  /'
    warn "Uncommitted changes in repo"
  else
    ok "Repo is clean"
  fi

  echo
  if (( ISSUES > 0 )); then
    echo "==> Doctor found $ISSUES issue(s). Run apply.sh to resolve most install drift."
    exit 1
  fi

  echo "==> All checks passed. No drift detected."
}

main "$@"
