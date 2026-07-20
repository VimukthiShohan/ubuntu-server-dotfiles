#!/usr/bin/env bash
# install-tools.sh - install developer CLIs not managed by apt.
# Bootstraps fnm/node, bun, pnpm, rust, and curl-installed CLIs. Idempotent.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"
# shellcheck source=lib/profile.sh
. "$SCRIPT_DIR/lib/profile.sh"
dotf_load_state_ro
FAILURES=()

run_pkg() {
  local label="$1"
  shift
  echo "  -> $label"
  if "$@"; then
    return 0
  fi
  echo "  !! failed: $label"
  FAILURES+=("$label")
  return 0
}

activate_fnm() {
  command -v fnm >/dev/null 2>&1 && return 0
  local d
  for d in "$HOME/.local/share/fnm" "$HOME/.fnm"; do
    if [[ -x "$d/fnm" ]]; then
      export PATH="$d:$PATH"
      return 0
    fi
  done
  return 1
}

ensure_node() {
  if ! activate_fnm; then
    echo "==> Installing fnm"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell || return 1
    activate_fnm || return 1
  fi

  activate_fnm || return 1
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$(command -v fnm)" "$HOME/.local/bin/fnm"
  eval "$(fnm env --shell bash)"

  echo "==> Ensuring node via fnm"
  fnm install --lts || return 1
  fnm default lts-latest || return 1
  fnm use lts-latest || return 1
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}

ensure_bun() {
  command -v bun >/dev/null 2>&1 && return 0
  echo "==> Installing bun"
  curl -fsSL https://bun.sh/install | bash || return 1
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  command -v bun >/dev/null 2>&1
}

ensure_pnpm() {
  command -v pnpm >/dev/null 2>&1 && return 0
  echo "==> Enabling pnpm with corepack"
  command -v corepack >/dev/null 2>&1 || return 1
  export PNPM_HOME="$HOME/.local/share/pnpm"
  mkdir -p "$PNPM_HOME"
  export PATH="$PNPM_HOME:$PATH"
  corepack enable pnpm || return 1
  command -v pnpm >/dev/null 2>&1
}

neovim_version_is_modern() {
  command -v nvim >/dev/null 2>&1 || return 1

  local first version major minor
  first="$(nvim --version | head -n 1)" || return 1
  version="${first#NVIM v}"
  version="${version%%-*}"

  IFS=. read -r major minor _ <<< "$version"
  [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 1
  (( major > 0 || minor >= 11 ))
}

ensure_neovim() {
  neovim_version_is_modern && return 0

  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "!! unsupported architecture for official Neovim release: $(uname -m)"
      return 1
      ;;
  esac

  echo "==> Installing Neovim from official release tarball"
  local archive dir install_dir tmp
  archive="nvim-linux-$arch.tar.gz"
  dir="nvim-linux-$arch"
  install_dir="$HOME/.local/share/$dir"
  tmp="$(mktemp -d)" || return 1
  # Self-clear the trap: a RETURN trap is global shell state, not function-local.
  # Without `trap - RETURN` it fires again when main() returns to the top level,
  # where $tmp is out of scope, and under `set -u` that aborts the whole run.
  trap 'rm -rf "$tmp"; trap - RETURN' RETURN

  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/$archive" -o "$tmp/$archive" || return 1
  tar -xzf "$tmp/$archive" -C "$tmp" || return 1

  mkdir -p "$HOME/.local/share" "$HOME/.local/bin" || return 1
  rm -rf "$install_dir" || return 1
  mv "$tmp/$dir" "$install_dir" || return 1
  ln -sfn "$install_dir/bin/nvim" "$HOME/.local/bin/nvim" || return 1
  hash -r 2>/dev/null || true

  neovim_version_is_modern
}

ensure_rust() {
  command -v cargo >/dev/null 2>&1 && return 0
  [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  command -v cargo >/dev/null 2>&1 && return 0
  echo "==> Installing rust via rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path || return 1
  [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  command -v cargo >/dev/null 2>&1
}

ensure_uv() {
  command -v uv >/dev/null 2>&1 && return 0
  echo "==> Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh || return 1
  export PATH="$HOME/.local/bin:$PATH"
  command -v uv >/dev/null 2>&1
}

check_go() {
  command -v go >/dev/null 2>&1 && return 0
  echo "!! go not found - install golang-go from setup/apt-packages.txt first."
  FAILURES+=("go (install via apt)")
  return 0
}

install_from_manifest() {
  local name="$1"
  local file="$2"
  local pm="$3"
  shift 3

  [[ -f "$file" ]] || return 0

  local raw
  raw="$(dotf_filter_manifest "$file")" || {
    FAILURES+=("$name manifest (structure error)")
    return 0
  }
  [[ -n "$raw" ]] || return 0

  if ! command -v "$pm" >/dev/null 2>&1; then
    echo "!! $pm not available - skipping $name manifest"
    FAILURES+=("$name manifest (no $pm)")
    return 0
  fi

  echo "==> Installing $name packages ($file)"
  local pkg
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    run_pkg "$name: $pkg" "$@" "$pkg"
  done <<< "$raw"
}

main() {
  export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$HOME/.fnm:$HOME/go/bin:$HOME/.cargo/bin:$PATH"

  echo "==> Bootstrapping package managers (profile: $DOTF_PROFILE)"
  if dotf_group_active nvim; then
    ensure_neovim || FAILURES+=("neovim bootstrap")
  fi
  if dotf_group_active node; then
    ensure_node || FAILURES+=("node/fnm bootstrap")
    ensure_bun  || FAILURES+=("bun bootstrap")
    ensure_pnpm || FAILURES+=("pnpm bootstrap")
  fi
  if dotf_group_active rust; then
    ensure_rust || FAILURES+=("rust bootstrap")
  fi
  if dotf_group_active python; then
    ensure_uv || FAILURES+=("uv bootstrap")
  fi
  if dotf_group_active go-tools; then
    check_go
  fi

  if [[ -f "$TOOLS_DIR/installers.sh" ]]; then
    echo "==> Installing shell-script CLIs (tools/installers.sh)"
    bash "$TOOLS_DIR/installers.sh" || FAILURES+=("shell-script installers")
  fi

  install_from_manifest "npm"   "$TOOLS_DIR/npm.txt"   npm   npm install -g
  install_from_manifest "bun"   "$TOOLS_DIR/bun.txt"   bun   bun add -g
  install_from_manifest "cargo" "$TOOLS_DIR/cargo.txt" cargo cargo install --locked
  install_from_manifest "go"    "$TOOLS_DIR/go.txt"    go    go install

  echo
  if (( ${#FAILURES[@]} )); then
    echo "==> Completed with ${#FAILURES[@]} issue(s):"
    local f
    for f in "${FAILURES[@]}"; do
      echo "    - $f"
    done
    echo "    Fix and re-run ~/.dotfiles/setup/install-tools.sh to retry."
  else
    echo "==> All developer CLIs installed."
  fi
}

main "$@"
