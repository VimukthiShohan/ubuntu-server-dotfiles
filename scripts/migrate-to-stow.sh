#!/usr/bin/env zsh
# migrate-to-stow.sh — one-time cutover to the multi-package Stow layout.
# Removes stale $HOME symlinks that point into ~/.dotfiles (both the old
# root-package links and the six leaked links), then re-stows the new packages
# under home/. Conservative: only removes symlinks whose target points into the
# dotfiles repo; never touches real files or unrelated symlinks. Safe to re-run.
set -euo pipefail

DOTFILES="$HOME/.dotfiles"

# remove_stale DIR DEPTH -> rm symlinks under DIR (to DEPTH) that point into the repo
remove_stale() {
  local dir="$1" depth="$2"
  [[ -d "$dir" ]] || return 0
  local link target
  while IFS= read -r link; do
    target="$(readlink "$link")"
    case "$target" in
      *.dotfiles/*)
        echo "    rm $link -> $target"
        rm "$link"
        ;;
    esac
  done < <(find "$dir" -maxdepth "$depth" -type l 2>/dev/null)
}

echo "==> Removing stale symlinks that point into $DOTFILES"
remove_stale "$HOME" 1
remove_stale "$HOME/.config" 1
remove_stale "$HOME/.ssh" 1

echo "==> Re-stowing packages"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/bin"
cd "$DOTFILES"
typeset -a packages
packages=(home/*(/N:t))
stow --adopt "${packages[@]}"

echo "==> Migration complete. Open a new shell to pick up the new links."
