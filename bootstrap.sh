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

verify_existing_clone() {
  local origin
  if ! origin="$(git -C "$TARGET" remote get-url origin 2>/dev/null)"; then
    echo "!! $TARGET exists but is not a git clone with an 'origin' remote." >&2
    echo "   Move it aside and re-run bootstrap." >&2
    exit 1
  fi
  case "$origin" in
    *VimukthiShohan/ubuntu-server-dotfiles*) ;;
    *)
      echo "!! $TARGET exists but its origin is '$origin', not ubuntu-server-dotfiles." >&2
      echo "   Move it aside (or set DOTFILES_DIR elsewhere) and re-run bootstrap." >&2
      exit 1
      ;;
  esac
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
