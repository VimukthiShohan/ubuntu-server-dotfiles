#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_absent_path() {
  local path="$1"
  [[ ! -e "$ROOT/$path" ]] || fail "$path should not exist in the Ubuntu branch"
}

assert_no_pattern() {
  local pattern="$1"
  local path="$2"
  if [[ -e "$ROOT/$path" ]] && grep -RInE "$pattern" "$ROOT/$path" >/tmp/ubuntu-config-test.out 2>/dev/null; then
    cat /tmp/ubuntu-config-test.out >&2
    fail "$path contains forbidden pattern: $pattern"
  fi
}

assert_contains() {
  local pattern="$1"
  local path="$2"
  grep -qE "$pattern" "$ROOT/$path" || fail "$path does not contain required pattern: $pattern"
}

assert_absent_path "setup/Brewfile"
assert_absent_path "setup/macos-defaults.sh"
assert_absent_path "home/ghostty"
assert_absent_path "home/zed"
assert_absent_path "home/yabai"
assert_absent_path "home/skhd"
assert_absent_path "home/ssh/.ssh/digis"
assert_absent_path "home/ssh/.ssh/github"
assert_absent_path "home/gh/.config/gh/hosts.yml"

assert_no_pattern '\b(brew|cask|mas|softwareupdate|xcode-select|dockutil|yabai|skhd|ghostty|zed)\b' "setup"
assert_no_pattern '/opt/homebrew|/Applications|Library/Application Support|Library/pnpm|Library/Android|pbcopy' "home/zsh"
assert_no_pattern 'nvm' "setup"
assert_no_pattern 'nvm' "home/zsh"

if grep -qxE 'lua-language-server|awscli' "$ROOT/setup/apt-packages.txt"; then
  fail "setup/apt-packages.txt should not declare unavailable Ubuntu 24.04 apt packages lua-language-server or awscli"
fi

for package in thefuck; do
  grep -qx "$package" "$ROOT/setup/apt-packages.txt" || fail "setup/apt-packages.txt should include Ubuntu package: $package"
done

if grep -qxE 'ruby-full|ruby-dev|rbenv' "$ROOT/setup/apt-packages.txt"; then
  fail "setup/apt-packages.txt should not install Ruby, rbenv, or Ruby headers for Android-only Ubuntu development"
fi

if grep -qx 'neovim' "$ROOT/setup/apt-packages.txt"; then
  fail "setup/apt-packages.txt should not install Ubuntu apt neovim because Noble ships an old version"
fi

assert_contains 'awscli-exe-linux-x86_64\.zip' "setup/tools/installers.sh"
assert_contains 'install_lua_language_server' "setup/tools/installers.sh"
assert_contains 'api\.github\.com/repos/LuaLS/lua-language-server/releases/latest' "setup/tools/installers.sh"
assert_contains 'install_zsh_completions' "setup/tools/installers.sh"
assert_contains 'zsh-users/zsh-completions' "setup/tools/installers.sh"
assert_no_pattern 'cocoapods|ensure_cocoapods|gem install|Gem\.user_dir' "setup/install-tools.sh"
assert_no_pattern 'Gem\.user_dir|ruby_gem' "home/zsh/.config/zsh/00-env.zsh"
assert_contains '\.zsh/zsh-completions/src' "home/zsh/.config/zsh/10-completion.zsh"
assert_contains 'install_from_manifest "cargo".*cargo install --locked' "setup/install-tools.sh"
assert_contains '^yazi-build$' "setup/tools/cargo.txt"
assert_no_pattern '^yazi-(fm|cli)$' "setup/tools/cargo.txt"
assert_contains '^rtk$' "setup/tools/cargo.txt"
assert_contains 'nvim-linux-\$arch\.tar\.gz' "setup/install-tools.sh"
assert_contains 'ln -sfn.*nvim.*"\$HOME/.local/bin/nvim"' "setup/install-tools.sh"
assert_contains 'command -v npm' "setup/install-tools.sh"
assert_no_pattern 'command -v node >/dev/null 2>&1 && return 0' "setup/install-tools.sh"
assert_contains '"\$HOME/.local/share/fnm"' "home/zsh/.config/zsh/00-env.zsh"
assert_contains 'ln -sfn.*fnm.*"\$HOME/.local/bin/fnm"' "setup/install-tools.sh"

assert_contains 'fnm\.vercel\.app/install' "setup/install-tools.sh"
assert_contains 'FNM_LOGLEVEL=quiet' "home/zsh/.config/zsh/00-env.zsh"
assert_contains 'PNPM_HOME="\$HOME/.local/share/pnpm"' "home/zsh/.config/zsh/00-env.zsh"
assert_contains 'ZDOTDIR="\${XDG_CONFIG_HOME:-\$HOME/.config}/zsh"' "home/zsh/.zshenv"
assert_contains 'ZSH_CONFIG_DIR="\${ZDOTDIR:-\${XDG_CONFIG_HOME:-\$HOME/.config}/zsh}"' "home/zsh/.config/zsh/.zshrc"
assert_contains 'default-shell /usr/bin/zsh' "home/tmux/.tmux.conf"
assert_contains 'default-command "/usr/bin/zsh -l"' "home/tmux/.tmux.conf"
assert_contains 'tmux source-file "\$HOME/.tmux.conf"' "apply.sh"
assert_contains 'exec zsh -l' "apply.sh"

# stow must run before the failure-prone steps (installers, services, chsh,
# repo clones) so an aborted run can never leave a machine without dotfiles.
if ! awk '
  /^  stow_dotfiles$/                       { stow = NR }
  /^  "\$DOTFILES\/setup\/install-tools\.sh"$/ { tools = NR }
  /^  configure_services$/                  { services = NR }
  /^  configure_login_shell$/               { shell = NR }
  /^  post_install_repos$/                  { repos = NR }
  END {
    exit !(stow && tools && services && shell && repos && \
           stow < tools && stow < services && stow < shell && stow < repos)
  }
' "$ROOT/apply.sh"; then
  fail "apply.sh must stow dotfiles before install-tools, services, login shell, and repo clones"
fi

# repo clones are network-dependent; a single flake must not abort the run.
assert_contains 'clone_repo_if_missing' "apply.sh"

if awk '
  /pcall\(function\(\)/ { guarded = 1 }
  /vim\.opt\.winborder[[:space:]]*=/ && !guarded { print FILENAME ":" FNR ":" $0; bad = 1 }
  guarded && /^end\)/ { guarded = 0 }
  END { exit bad }
' "$ROOT/home/nvim/.config/nvim/lua/config/set.lua" >/tmp/ubuntu-config-test.out; then
  :
else
  cat /tmp/ubuntu-config-test.out >&2
  fail "Neovim winborder must be guarded because Ubuntu 24.04 ships Neovim 0.9"
fi

if (( failures > 0 )); then
  exit 1
fi

echo "Ubuntu config checks passed"
