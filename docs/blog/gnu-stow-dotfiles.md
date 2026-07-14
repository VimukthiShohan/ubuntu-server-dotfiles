---
title: How to Manage Dotfiles with GNU Stow (and Rebuild Your Whole Ubuntu Server in One Command)
published: false
description: A practical guide to managing dotfiles with GNU Stow, plus the idempotent bash scripts that turn a fresh Ubuntu 24.04 server into a full dev environment.
tags: linux, ubuntu, bash, productivity
canonical_url:
---

Every time I got a fresh Ubuntu VPS, I lost half a day to the same ritual: install zsh, copy over my `.zshrc`, remember which tools I had on the old machine, fix the `bat` vs `batcat` mess, reconfigure tmux, and inevitably discover a missing CLI a week later mid-task.

The fix was two things working together: **GNU Stow** for the config files, and a small set of **idempotent bash scripts** for everything Stow can't do (packages, services, login shell). Now a new server goes from bare Ubuntu 24.04 to my complete dev environment with one script, and I can re-run it any time without breaking anything.

This post walks through the whole setup as released in **v1.0.0**, then where it's heading next: from a collection of scripts to a proper CLI-driven tool. The full repo is on GitHub: [ubuntu-server-dotfiles](https://github.com/VimukthiShohan/ubuntu-server-dotfiles).

## What is GNU Stow, and why use it for dotfiles?

GNU Stow is a symlink farm manager. You keep your real config files in a git repo, organized into "packages" that mirror your home directory, and Stow creates symlinks from `$HOME` into the repo:

```
dotfiles/home/
├── zsh/
│   ├── .zshenv                →  ~/.zshenv
│   └── .config/zsh/
│       ├── 00-env.zsh         →  ~/.config/zsh/00-env.zsh
│       └── 30-aliases.zsh     →  ~/.config/zsh/30-aliases.zsh
├── git/
│   ├── .gitconfig             →  ~/.gitconfig
│   └── .config/git/ignore     →  ~/.config/git/ignore
├── tmux/
│   └── .tmux.conf             →  ~/.tmux.conf
└── nvim/
    └── .config/nvim/          →  ~/.config/nvim/
```

One command links a package into place:

```bash
stow -d home -t ~ zsh git tmux nvim
```

Why Stow instead of copying files or a bare git repo?

- **Edits are live.** The file in `~/.config/nvim/` *is* the file in the repo. Change it, test it, commit it — no sync step.
- **Per-tool packages.** Each tool gets its own directory, so you can stow `nvim` on one machine and skip it on another.
- **Uninstall is clean.** `stow -D nvim` removes exactly the symlinks it created, nothing else.
- **It's already in apt.** `sudo apt install stow` — no bootstrap chicken-and-egg like some dotfile managers.

A `.stowrc` file in the repo root means you never have to remember the flags:

```
--dir=home
--target=~
```

## The part Stow can't do: packages, tools, and services

Symlinked configs are useless if `zsh`, `tmux`, and `nvim` aren't installed. This is where most dotfiles repos stop and mine keeps going: **everything installable lives in a plain-text manifest**, one item per line, `#` for comments.

```
setup/
├── apt-packages.txt      # apt CLI + service packages
├── install-tools.sh      # Neovim tarball, fnm/node, bun, pnpm, rust, uv
└── tools/
    ├── npm.txt           # npm install -g
    ├── bun.txt           # bun add -g
    ├── cargo.txt         # cargo install --locked
    ├── go.txt            # go install
    └── installers.sh     # guarded curl installers (aws-cli, etc.)
```

The rule that makes this work: **if a tool isn't in a manifest, it doesn't exist.** Never hand-install something on a server and call it done — add it to the manifest, re-run the apply script, commit. The manifest is the machine.

Reading a manifest in bash is three lines:

```bash
read_manifest() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$file" || true
}
```

## An idempotent apply script

`apply.sh` converges the machine to the declared state. The key word is *converges* — it's safe to run on a fresh server or a fully configured one, because every step checks before it acts:

```bash
# Clone only if missing
[[ -d "$HOME/.tmux/plugins/tpm" ]] || \
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

# Change login shell only if it isn't already zsh
if [[ "${SHELL:-}" == "$zsh_path" ]]; then
  echo "  -> $USER already uses $zsh_path"
  return 0
fi
sudo chsh -s "$zsh_path" "$USER"

# Add to docker group only if not already a member
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
fi
```

It also fixes a classic Ubuntu papercut automatically. On Ubuntu, `bat` installs as `batcat` and `fd` as `fdfind` (name collisions with older packages), which breaks every alias and script that expects the real names. The apply script shims them once:

```bash
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
fi
```

The whole pipeline is: apt manifest → command shims → language toolchains → docker service → zsh as login shell → clone tmux/prompt plugins → `stow` everything → reload tmux config. Run it after every manifest or dotfile change.

## Handling stow conflicts on an existing machine

The first run on a machine that already has a `.zshrc` will fail with a stow conflict — Stow refuses to overwrite real files. That's what `--adopt` is for:

```bash
stow -d home -t ~ --adopt zsh git tmux
```

`--adopt` moves the *existing* file into your repo and replaces it with a symlink. Then `git diff` shows you exactly how the machine's config differed from your repo, and you decide: keep the machine's version (commit it) or restore yours (`git restore .`). My `apply.sh --fresh` flag enables this for first-time setup only — you don't want adoption silently pulling drift into your repo on routine runs.

## A doctor script that never mutates

The third piece is `doctor.sh`: a **strictly read-only** drift check. It verifies the platform is Ubuntu, every apt package in the manifest is installed, required commands exist, plugin repos are cloned, and — the neat trick — runs Stow in dry-run mode to detect symlink conflicts without touching anything:

```bash
stow -d "$DOTFILES/home" -t "$HOME" --no --verbose "${packages[@]}" 2>&1
```

It exits 1 if anything drifted, so you can even run it from cron or CI. The separation matters: `doctor.sh` diagnoses, `apply.sh` heals, and neither surprises you.

## Keeping secrets out of the repo

Dotfiles repos are public. Machine identity is not. Two untracked files handle everything machine-specific:

```bash
# Git identity — the stowed .gitconfig includes this file
git config --file ~/.gitconfig.local user.name "Your Name"
git config --file ~/.gitconfig.local user.email "you@example.com"
```

```bash
# ~/.config/zsh/local.zsh — sourced last by the stowed zsh config
export SOME_API_KEY=...
```

The repo never contains SSH keys, GitHub auth state (`gh`'s `hosts.yml`), or tokens — and a static test (`tests/ubuntu-config.bash`) fails the build if a forbidden pattern ever sneaks into a tracked file.

## Putting it together: fresh server in one command

On a brand-new Ubuntu 24.04 server (as of v1.0.0):

```bash
git clone https://github.com/VimukthiShohan/ubuntu-server-dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup.sh
```

`setup.sh` installs the prerequisites via apt and calls `apply.sh --fresh`. From then on, the routine on any machine is:

```bash
cd ~/.dotfiles && git pull && ./doctor.sh && ./apply.sh
```

## What's next (v2.0.0): from script collection to CLI

That routine still means remembering three script names and where the repo lives. The next release turns the repo into a CLI-driven tool while keeping every script above exactly as it is. Two additions, both plain bash:

**A true one-liner for fresh servers.** No clone-then-cd dance — a `bootstrap.sh` at the repo root becomes the curl target:

```bash
curl -fsSL https://raw.githubusercontent.com/VimukthiShohan/ubuntu-server-dotfiles/main/bootstrap.sh | bash
```

It gates on Ubuntu, installs git if needed, clones the repo over HTTPS to `~/.dotfiles`, and runs `setup.sh`. Safe to re-run, and it refuses to touch a `~/.dotfiles` directory that isn't actually this repo.

**A `dotf` command for daily use.** Installed by Stow itself (it's just another package, `home/dotf/`, linking into `~/.local/bin`), so the tool that manages the dotfiles is managed like a dotfile:

| command | does |
|---|---|
| `dotf apply [--fresh]` | converge the machine (`apply.sh`) |
| `dotf doctor` | read-only drift check (`doctor.sh`) |
| `dotf update` | `git pull --ff-only`, then converge |
| `dotf test` | the repo's static guard + syntax checks |

The design rule making this safe is what I'd call a **veneer**: `dotf` only delegates to the existing scripts and is forbidden — by the repo's own static tests — from containing any `apt-get`, `stow`, or `sudo` of its own. The scripts stay the single source of converge logic; the CLI is ergonomics. Even finding the repo needs zero config: `dotf` resolves its own symlink back through Stow to discover where the clone lives.

The daily routine collapses to:

```bash
dotf update   # pull + converge
dotf doctor   # am I drifted?
```

## FAQ

**GNU Stow vs a bare git repo for dotfiles?**
A bare repo tracks files in place but gives you no per-tool grouping and no clean uninstall. Stow's package model means each tool is opt-in per machine, and `stow -D` cleanly removes one tool's links. Stow also can't accidentally clobber files — conflicts are errors unless you explicitly `--adopt`.

**GNU Stow vs chezmoi/dotbot?**
Chezmoi is more powerful (templating, secrets integration) but it's another tool with its own DSL to learn and bootstrap. Stow is one apt package, zero config, and plain symlinks you can inspect with `ls -la`. For a server environment where the "templating" is just two untracked local files, Stow is enough.

**Why fnm instead of nvm?**
fnm is a single fast binary with proper shell integration and no 3,000-line shell function slowing every prompt. The repo's static guard actually rejects any `nvm` reference.

**Why a bash CLI instead of an npm package or a Go/Rust binary?**
Chicken-and-egg: a fresh server has no Node, no cargo, no prebuilt binary — but it always has bash. A stowed bash script needs zero new toolchain, and the bootstrap one-liner only assumes `curl`, which ships in Ubuntu's cloud images.

**Does this work on macOS?**
Stow itself does, but this repo is intentionally Ubuntu-server-only — no brew, no GUI apps, no desktop settings. Keeping the scope narrow is what keeps `apply.sh` reliable.

---

The complete setup — scripts, manifests, and all stow packages — is at [github.com/VimukthiShohan/ubuntu-server-dotfiles](https://github.com/VimukthiShohan/ubuntu-server-dotfiles). v1.0.0 is the script collection described above; v2.0.0 adds the bootstrap one-liner and the `dotf` CLI. Clone it, gut my configs, keep the skeleton.
