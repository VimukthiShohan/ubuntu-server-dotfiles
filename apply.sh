#!/usr/bin/env bash
# apply.sh - converge this Ubuntu server to the declared dotfiles state.
# Usage: ./apply.sh [--fresh]
#   --fresh  use stow --adopt for first-time conflict handling.

set -euo pipefail
trap 'echo "!! apply.sh: step above failed. Fix it, then re-run this script."' ERR

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APT_PACKAGES="$DOTFILES/setup/apt-packages.txt"
FRESH=0
[[ "${1:-}" == "--fresh" ]] && FRESH=1
CLONE_FAILURES=()

section() {
  echo
  echo "==> $*"
}

read_manifest() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$file" || true
}

install_apt_packages() {
  section "Installing apt CLI and service packages"
  sudo -v
  sudo apt-get update

  local failures=()
  local package
  while IFS= read -r package; do
    [[ -n "$package" ]] || continue
    echo "  -> $package"
    if ! sudo apt-get install -y "$package"; then
      failures+=("$package")
    fi
  done < <(read_manifest "$APT_PACKAGES")

  if (( ${#failures[@]} )); then
    echo
    echo "!! Some apt packages failed to install:"
    printf '   - %s\n' "${failures[@]}"
    echo "   Fix the package names or enable the needed apt repository, then re-run apply.sh."
  fi
}

create_ubuntu_command_shims() {
  section "Creating Ubuntu command shims"
  mkdir -p "$HOME/.local/bin"

  if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi

  if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
}

configure_services() {
  section "Configuring services"

  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files docker.service >/dev/null 2>&1; then
    sudo systemctl enable --now docker
    if ! id -nG "$USER" | grep -qw docker; then
      sudo usermod -aG docker "$USER"
      echo "  -> Added $USER to docker group. Log out and back in before using docker without sudo."
    fi
  else
    echo "  -> docker service not present; skipping"
  fi
}

configure_login_shell() {
  section "Configuring login shell"

  if ! command -v zsh >/dev/null 2>&1; then
    echo "  -> zsh not found; skipping"
    return 0
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    echo "  -> $USER already uses $zsh_path"
    return 0
  fi

  if ! grep -qxF "$zsh_path" /etc/shells; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi

  sudo chsh -s "$zsh_path" "$USER"
  echo "  -> Changed $USER login shell to $zsh_path. Log out and back in to use it."
}

clone_repo_if_missing() {
  local dest="$1"
  shift
  [[ -d "$dest" ]] && return 0
  if ! git clone "$@" "$dest"; then
    echo "  !! clone failed: $dest — re-run apply.sh to retry."
    CLONE_FAILURES+=("$dest")
  fi
}

post_install_repos() {
  section "Post-install repos"
  clone_repo_if_missing "$HOME/.fzf-git.sh" https://github.com/junegunn/fzf-git.sh.git
  clone_repo_if_missing "$HOME/.tmux/plugins/tpm" https://github.com/tmux-plugins/tpm
  clone_repo_if_missing "$HOME/powerlevel10k" --depth=1 https://github.com/romkatv/powerlevel10k.git
}

stow_dotfiles() {
  section "Stowing dotfiles"
  mkdir -p "$HOME/.config"

  local packages=()
  local package_path
  while IFS= read -r package_path; do
    packages+=("$(basename "$package_path")")
  done < <(find "$DOTFILES/home" -mindepth 1 -maxdepth 1 -type d | sort)

  if (( ${#packages[@]} == 0 )); then
    echo "!! No stow packages found under $DOTFILES/home"
    exit 1
  fi

  if (( FRESH )); then
    stow -d "$DOTFILES/home" -t "$HOME" --adopt "${packages[@]}"
  else
    stow -d "$DOTFILES/home" -t "$HOME" "${packages[@]}"
  fi
}

reload_tmux_config() {
  section "Reloading tmux config"

  if ! command -v tmux >/dev/null 2>&1; then
    echo "  -> tmux not found; skipping"
    return 0
  fi

  if tmux ls >/dev/null 2>&1; then
    tmux source-file "$HOME/.tmux.conf" || true
    tmux set-option -g default-shell /usr/bin/zsh || true
    tmux set-option -g default-command "/usr/bin/zsh -l" || true
    echo "  -> Existing tmux panes keep their current shell."
    echo "     Run 'exec zsh -l' in old bash panes, or restart tmux with 'tmux kill-server' once."
  else
    echo "  -> no tmux server running"
  fi
}

main() {
  install_apt_packages
  create_ubuntu_command_shims

  # Stow first: it is local and cheap, and linking the dotfiles must never be
  # hostage to the network/privileged steps below aborting the run.
  stow_dotfiles

  section "Installing developer CLIs and package managers"
  "$DOTFILES/setup/install-tools.sh"

  configure_services
  configure_login_shell
  post_install_repos
  reload_tmux_config

  echo
  if (( ${#CLONE_FAILURES[@]} )); then
    echo "==> Apply complete with ${#CLONE_FAILURES[@]} clone failure(s) — re-run ./apply.sh to retry."
    exit 1
  fi
  echo "==> Apply complete."
}

main "$@"
