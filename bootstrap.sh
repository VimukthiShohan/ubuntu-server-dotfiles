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
shopt -s inherit_errexit   # command-substitution failures must abort, never fail open
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

main "$@"
