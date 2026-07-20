#!/usr/bin/env bash
# bootstrap.sh - fresh Ubuntu server -> converged machine in one step.
# Usage (download-then-run, so a truncated download can never execute a partial
# script or report false success):
#   f=$(mktemp) && curl -fsSL https://raw.githubusercontent.com/VimukthiShohan/ubuntu-server-dotfiles/main/bootstrap.sh -o "$f" && bash "$f"
# Precondition: run as a non-root user with sudo access.
#
# Whole script is functions with a trailing `main "$@"` so nothing executes until
# bash has parsed the full file, and main detaches stdin so no inner command can
# eat streamed script text.

set -euEo pipefail
shopt -s inherit_errexit 2>/dev/null || true   # bash 4.4+; degrades to a no-op under 3.2 (guard sources this file)
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

# Run git with config-driven code execution and transport redirection neutralized:
# a planted .git/config or the invoking user's global/system config (fsmonitor,
# hooks, credential/ssh helpers, url.*.insteadOf, http.proxy, http.sslVerify=false)
# must not be able to run commands or repoint a fetch before we've confirmed the
# code is genuinely upstream. GIT_CONFIG_GLOBAL=/dev/null drops ~/.gitconfig and
# GIT_CONFIG_NOSYSTEM=1 drops /etc/gitconfig; the -c overrides force TLS verification
# and forbid the file://, ext:: and other non-HTTPS transports an insteadOf could
# rewrite to. Used with no -C for the initial clone, and via verified_git for
# in-repo operations on the not-yet-verified $TARGET.
git_hardened() {
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git \
    -c core.fsmonitor= \
    -c core.hooksPath=/dev/null \
    -c credential.helper= \
    -c core.sshCommand= \
    -c http.sslVerify=true \
    -c protocol.file.allow=never \
    -c protocol.ext.allow=never \
    "$@"
}

verified_git() {
  git_hardened -C "$TARGET" "$@"
}

# Verify $TARGET is genuinely this upstream repo at origin/main with a clean tree,
# then it is safe to execute its setup.sh. Runs for both a freshly cloned $TARGET
# and a pre-existing one — the fresh clone is not trusted until it passes here too.
verify_clone() {
  local origin canonical
  if ! origin="$(verified_git remote get-url origin 2>/dev/null)"; then
    echo "!! $TARGET exists but is not a git checkout with an 'origin' remote." >&2
    echo "   Move it aside and re-run bootstrap." >&2
    exit 1
  fi

  canonical="$(normalize_repo_url "$REPO_HTTPS")"
  if [[ "$(normalize_repo_url "$origin")" != "$canonical" ]]; then
    echo "!! $TARGET exists but its origin is '$origin', not ubuntu-server-dotfiles." >&2
    echo "   Move it aside (or set DOTFILES_DIR elsewhere) and re-run bootstrap." >&2
    exit 1
  fi

  # Fetch the literal canonical URL, not the 'origin' remote name, so a repointed
  # origin cannot redirect the fetch to attacker-controlled content.
  if ! verified_git fetch --no-tags "$REPO_HTTPS" main; then
    echo "!! Failed to fetch main from $REPO_HTTPS into $TARGET (see error above)." >&2
    echo "   Check network access, or move $TARGET aside and re-run bootstrap." >&2
    exit 1
  fi

  local status_out
  if ! status_out="$(verified_git status --porcelain --ignored)"; then
    echo "!! Failed to read git status in $TARGET; refusing to run an unverified tree." >&2
    echo "   Inspect/move aside $TARGET (or set DOTFILES_DIR elsewhere) and re-run." >&2
    exit 1
  fi
  if [[ -n "$status_out" ]]; then
    echo "!! $TARGET has local changes (modified, untracked, and/or ignored files)." >&2
    echo "   bootstrap refuses to run a tree it hasn't verified matches upstream." >&2
    echo "   If these are intentional edits, run './apply.sh' (or 'dotf apply') in" >&2
    echo "   $TARGET directly instead of bootstrap. Otherwise inspect/move aside" >&2
    echo "   $TARGET (or set DOTFILES_DIR elsewhere) and re-run bootstrap." >&2
    exit 1
  fi

  local head fetch_head
  head="$(verified_git rev-parse HEAD)"
  fetch_head="$(verified_git rev-parse FETCH_HEAD)"
  if [[ "$head" != "$fetch_head" ]]; then
    echo "!! $TARGET's HEAD ($head) does not match upstream origin/main ($fetch_head)." >&2
    echo "   bootstrap refuses to run a tree it hasn't verified matches upstream." >&2
    echo "   Run './apply.sh' (or 'dotf apply') in $TARGET directly, or update it" >&2
    echo "   yourself (e.g. 'git -C $TARGET pull') and re-run bootstrap." >&2
    exit 1
  fi
}

dotf_valid_username() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]*$ ]]
}

# Hardened key copy: resolve home/group from the system, never follow or
# overwrite through symlinks, install with exact modes/ownership.
copy_authorized_keys() {
  local username="$1" home group src="$HOME/.ssh/authorized_keys"
  if [[ ! -f "$src" ]]; then
    echo "  !! no $src to copy — set up SSH access for '$username' manually."
    return 0
  fi
  home="$(getent passwd "$username" | cut -d: -f6)"
  group="$(id -gn "$username")"
  if [[ -z "$home" || -z "$group" ]]; then
    echo "  !! cannot resolve home/group for '$username'; skipping key copy." >&2
    return 0
  fi
  if [[ -L "$home/.ssh" || -L "$home/.ssh/authorized_keys" ]]; then
    echo "  !! $home/.ssh contains symlinks; refusing to copy keys." >&2
    return 0
  fi
  sudo install -d -m 700 -o "$username" -g "$group" "$home/.ssh"
  sudo install -m 600 -o "$username" -g "$group" "$src" "$home/.ssh/authorized_keys"
  echo "  -> authorized_keys copied to $home/.ssh/"
}

# Optional new-user creation + total handoff. One-shot: the re-exec'd copy
# runs with DOTF_BOOTSTRAP_HANDOFF=1 and skips this entirely. The parent
# exits right after the handoff — nothing installs for the original account.
maybe_create_new_user() {
  [[ "${DOTF_BOOTSTRAP_HANDOFF:-}" == "1" ]] && return 0
  # Probe /dev/tty by actually opening it (read+write). Its permission bits are
  # 0666 even with no controlling terminal, so a plain -r/-w test would look
  # interactive and then crash on the first prompt; opening it is the only
  # reliable detection.
  { : >/dev/tty && : </dev/tty; } 2>/dev/null || return 0

  local answer username script_copy
  printf 'Create a new user for this setup? [y/N] ' > /dev/tty
  IFS= read -r answer < /dev/tty || return 0
  [[ "$answer" =~ ^[Yy]$ ]] || return 0

  while :; do
    printf 'Username: ' > /dev/tty
    IFS= read -r username < /dev/tty || return 0
    if ! dotf_valid_username "$username"; then
      echo "  !! invalid username (must match ^[a-z_][a-z0-9_-]*\$)" > /dev/tty
      continue
    fi
    if getent passwd "$username" >/dev/null 2>&1; then
      echo "  !! user '$username' already exists — existing accounts are never reused; pick a new name." > /dev/tty
      continue
    fi
    break
  done

  echo "==> Creating user '$username' (you will set their password)"
  sudo adduser "$username" </dev/tty >/dev/tty 2>&1
  sudo usermod -aG sudo "$username"
  copy_authorized_keys "$username"

  # The mktemp download is 0600 to this user; hand the new user a readable copy.
  script_copy="$(mktemp /tmp/dotf-bootstrap.XXXXXX)"
  cp "${BASH_SOURCE[0]}" "$script_copy"
  chmod 644 "$script_copy"

  echo "==> Handing installation off to '$username' (sudo will ask for THEIR password)"
  sudo -u "$username" -H env DOTF_BOOTSTRAP_HANDOFF=1 bash "$script_copy"
  exit $?
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
  if [[ "${VERSION_ID:-}" != "24.04" && "${DOTF_SKIP_VERSION_CHECK:-}" != "1" ]]; then
    echo "!! bootstrap.sh targets Ubuntu 24.04. Detected VERSION_ID='${VERSION_ID:-unknown}'." >&2
    echo "   The apt and tool manifests are Noble-specific and may fail elsewhere." >&2
    echo "   Set DOTF_SKIP_VERSION_CHECK=1 to override and proceed at your own risk." >&2
    exit 1
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    echo "!! Run bootstrap as a non-root user with sudo, not as root." >&2
    exit 1
  fi

  maybe_create_new_user

  if ! command -v git >/dev/null 2>&1; then
    echo "==> Installing git"
    sudo apt-get update
    sudo apt-get install -y git
  fi

  if [[ -e "$TARGET" ]]; then
    echo "==> $TARGET already exists; verifying it is this repo"
  else
    echo "==> Cloning dotfiles to $TARGET"
    git_hardened clone --branch main "$REPO_HTTPS" "$TARGET"
  fi

  # Verify unconditionally: a freshly cloned tree is not trusted until it passes.
  verify_clone

  echo "==> Running setup"
  "$TARGET/setup.sh"

  echo
  echo "==> Bootstrap complete. Start a new login shell (log out and back in);"
  echo "    'dotf' is then on PATH: dotf apply | doctor | update | test"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
