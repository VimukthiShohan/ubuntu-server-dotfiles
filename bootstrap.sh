#!/usr/bin/env bash
# bootstrap.sh - fresh Ubuntu server -> converged machine in one step.
# Usage: curl -fsSL https://raw.githubusercontent.com/VimukthiShohan/ubuntu-server-dotfiles/main/bootstrap.sh | bash
# Precondition: run as a non-root user with sudo access.
#
# Whole script is functions with a trailing `main "$@"` so nothing executes
# until bash has parsed the full file (required for `curl | bash`), and main
# detaches stdin so no inner command can eat streamed script text.

set -euEo pipefail
trap 'echo "!! bootstrap.sh: step above failed. Fix it, then re-run this script."' ERR

REPO_HTTPS="https://github.com/VimukthiShohan/ubuntu-server-dotfiles.git"
TARGET="${DOTFILES_DIR:-$HOME/.dotfiles}"

normalize_repo_url() {
  local u="$1"
  u="${u%/}"
  u="${u%.git}"
  u="${u%/}"
  printf '%s' "$u"
}

verify_existing_clone() {
  local origin canonical
  if ! origin="$(git -C "$TARGET" remote get-url origin 2>/dev/null)"; then
    echo "!! $TARGET exists but is not a git clone with an 'origin' remote." >&2
    echo "   Move it aside and re-run bootstrap." >&2
    exit 1
  fi

  canonical="$(normalize_repo_url "$REPO_HTTPS")"
  if [[ "$(normalize_repo_url "$origin")" != "$canonical" ]]; then
    echo "!! $TARGET exists but its origin is '$origin', not ubuntu-server-dotfiles." >&2
    echo "   Move it aside (or set DOTFILES_DIR elsewhere) and re-run bootstrap." >&2
    exit 1
  fi

  if ! git -C "$TARGET" fetch origin main; then
    echo "!! Failed to fetch 'origin main' in $TARGET (see error above)." >&2
    echo "   Check network access, or move $TARGET aside and re-run bootstrap." >&2
    exit 1
  fi

  if [[ -n "$(git -C "$TARGET" status --porcelain)" ]]; then
    echo "!! $TARGET has local changes (modified and/or untracked files)." >&2
    echo "   bootstrap refuses to run a tree it hasn't verified matches upstream." >&2
    echo "   If these are intentional edits, run './apply.sh' (or 'dotf apply') in" >&2
    echo "   $TARGET directly instead of bootstrap. Otherwise inspect/move aside" >&2
    echo "   $TARGET (or set DOTFILES_DIR elsewhere) and re-run bootstrap." >&2
    exit 1
  fi

  local head fetch_head
  head="$(git -C "$TARGET" rev-parse HEAD)"
  fetch_head="$(git -C "$TARGET" rev-parse FETCH_HEAD)"
  if [[ "$head" != "$fetch_head" ]]; then
    echo "!! $TARGET's HEAD ($head) does not match upstream origin/main ($fetch_head)." >&2
    echo "   bootstrap refuses to run a tree it hasn't verified matches upstream." >&2
    echo "   Run './apply.sh' (or 'dotf apply') in $TARGET directly, or update it" >&2
    echo "   yourself (e.g. 'git -C $TARGET pull') and re-run bootstrap." >&2
    exit 1
  fi
}

main() {
  exec </dev/null

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  fi
  if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "!! bootstrap.sh targets Ubuntu. Detected ID='${ID:-unknown}'." >&2
    exit 1
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    echo "!! Run bootstrap as a non-root user with sudo, not as root." >&2
    exit 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "==> Installing git"
    sudo apt-get update
    sudo apt-get install -y git
  fi

  if [[ -e "$TARGET" ]]; then
    echo "==> $TARGET already exists; verifying it is this repo"
    verify_existing_clone
  else
    echo "==> Cloning dotfiles to $TARGET"
    git clone "$REPO_HTTPS" "$TARGET"
  fi

  echo "==> Running setup"
  "$TARGET/setup.sh"

  echo
  echo "==> Bootstrap complete. Start a new login shell (log out and back in);"
  echo "    'dotf' is then on PATH: dotf apply | doctor | update | test"
}

main "$@"
