#!/usr/bin/env bash
# CLIs distributed via shell-script installers. Each block is idempotent.

set -u

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

install_aws_cli() {
  local tmp
  tmp="$(mktemp -d)" || return 1
  trap 'rm -rf "$tmp"' RETURN

  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmp/awscliv2.zip" || return 1
  unzip -q "$tmp/awscliv2.zip" -d "$tmp" || return 1
  "$tmp/aws/install" -i "$HOME/.local/aws-cli" -b "$HOME/.local/bin" --update || return 1
}

install_lua_language_server() {
  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "  !! unsupported architecture for lua-language-server: $(uname -m)"
      return 1
      ;;
  esac

  local tmp url install_dir
  tmp="$(mktemp -d)" || return 1
  trap 'rm -rf "$tmp"' RETURN

  url="$(curl -fsSL https://api.github.com/repos/LuaLS/lua-language-server/releases/latest \
    | jq -r --arg suffix "linux-$arch.tar.gz" '.assets[] | select(.name | endswith($suffix)) | .browser_download_url' \
    | head -n 1)"
  [[ -n "$url" && "$url" != "null" ]] || return 1

  install_dir="$HOME/.local/share/lua-language-server"
  mkdir -p "$HOME/.local/bin" "$install_dir" || return 1
  curl -fsSL "$url" -o "$tmp/lua-language-server.tar.gz" || return 1
  rm -rf "$install_dir" || return 1
  mkdir -p "$install_dir" || return 1
  tar -xzf "$tmp/lua-language-server.tar.gz" -C "$install_dir" || return 1
  ln -sfn "$install_dir/bin/lua-language-server" "$HOME/.local/bin/lua-language-server" || return 1
}

install_zsh_completions() {
  local repo="$HOME/.zsh/zsh-completions"
  mkdir -p "$HOME/.zsh" || return 1

  if [[ -d "$repo/.git" ]]; then
    git -C "$repo" pull --ff-only || return 1
  else
    git clone --depth=1 https://github.com/zsh-users/zsh-completions "$repo" || return 1
  fi
}

if ! command -v aws >/dev/null 2>&1; then
  echo "  -> installing aws cli v2"
  install_aws_cli
fi

if ! command -v lua-language-server >/dev/null 2>&1; then
  echo "  -> installing lua-language-server"
  install_lua_language_server
fi

if [[ ! -d "$HOME/.zsh/zsh-completions/src" ]]; then
  echo "  -> installing zsh-completions"
  install_zsh_completions
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "  -> installing claude code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "  -> installing opencode"
  curl -fsSL https://opencode.ai/install | bash
fi
