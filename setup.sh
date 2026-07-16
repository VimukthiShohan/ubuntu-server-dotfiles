#!/usr/bin/env bash
# setup.sh - fresh Ubuntu bootstrap. Installs prerequisites, then delegates to apply.sh --fresh.

set -euEo pipefail
trap 'echo "!! setup.sh: step above failed. Fix it, then re-run this script."' ERR

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  fi

  if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "!! This branch targets Ubuntu. Detected ID='${ID:-unknown}'."
    exit 1
  fi

  echo "==> Refreshing apt metadata"
  sudo -v
  sudo apt-get update

  echo "==> Installing bootstrap prerequisites"
  sudo apt-get install -y ca-certificates curl git sudo zsh stow software-properties-common
  sudo add-apt-repository -y universe || true
  sudo apt-get update

  echo "==> Running full apply (fresh mode)"
  "$DOTFILES/apply.sh" --fresh
}

main "$@"
