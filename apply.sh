#!/usr/bin/env bash
# apply.sh - converge this Ubuntu server to the declared dotfiles state.
# Usage: ./apply.sh [--fresh]
#   --fresh  use stow --adopt for first-time conflict handling.

set -euEo pipefail
trap 'echo "!! apply.sh: step above failed. Fix it, then re-run this script."' ERR

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup/lib/profile.sh
. "$DOTFILES/setup/lib/profile.sh"
dotf_load_state_ro
APT_PACKAGES="$DOTFILES/setup/apt-packages.txt"
FRESH=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fresh) FRESH=1 ;;
    -h|--help) echo "Usage: apply.sh [--fresh]"; exit 0 ;;
    *) echo "!! apply.sh: unknown argument '$1' (accepts only --fresh)." >&2
       echo "   Usage: apply.sh [--fresh]" >&2
       exit 1 ;;
  esac
  shift
done
CLONE_FAILURES=()

section() {
  echo
  echo "==> $*"
}

install_apt_packages() {
  section "Installing apt CLI and service packages (profile: $DOTF_PROFILE)"
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
  done < <(dotf_filter_manifest "$APT_PACKAGES")

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

  if ! dotf_group_active services; then
    echo "  -> services group inactive; skipping"
    return 0
  fi

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
  if [[ -d "$dest" ]]; then
    # A completed clone has a resolvable HEAD. A dir left partial by an
    # interrupted clone (or otherwise not a healthy repo) is removed and retried
    # so the run makes good on its "re-run to retry" promise instead of skipping
    # a broken checkout forever.
    if git -C "$dest" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
      return 0
    fi
    echo "  !! $dest exists but is not a healthy git repo — removing and re-cloning."
    rm -rf "$dest"
  fi
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
  # stow calls getcwd() internally; if the inherited CWD is inaccessible (e.g. a
  # new-user handoff still sitting in the previous user's 0750 home) it aborts with
  # "current directory ... seems to have vanished". Anchor to the repo, always readable.
  cd "$DOTFILES"
  mkdir -p "$HOME/.config"
  mkdir -p "$HOME/.local/bin"

  local packages=()
  local package
  while IFS= read -r package; do
    [[ -d "$DOTFILES/home/$package" ]] || {
      echo "!! stow package '$package' missing under $DOTFILES/home" >&2
      exit 1
    }
    packages+=("$package")
  done < <(dotf_stow_packages)

  if (( ${#packages[@]} == 0 )); then
    echo "!! No stow packages resolved for profile '$DOTF_PROFILE'"
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

  section "Installing developer CLIs and package managers (profile: $DOTF_PROFILE)"
  "$DOTFILES/setup/install-tools.sh"

  configure_services
  configure_login_shell
  post_install_repos
  reload_tmux_config

  if dotf_group_active ai-clis && [[ -x "$DOTFILES/setup/skills.sh" ]]; then
    section "AI skill frameworks"
    "$DOTFILES/setup/skills.sh" || true
  fi

  echo
  if (( ${#CLONE_FAILURES[@]} )); then
    echo "!! WARNING: Apply complete, but ${#CLONE_FAILURES[@]} repo clone(s) failed (network?):"
    printf '   - %s\n' "${CLONE_FAILURES[@]}"
    echo "   Re-run ./apply.sh to retry the missing clone(s); everything else converged."
    exit 0
  fi
  echo "==> Apply complete."
}

main "$@"
