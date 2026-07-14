# Ubuntu Server Dotfiles

A complete Ubuntu 24.04 server development environment in one repo. It is
intentionally CLI and service focused: no desktop apps, no GUI terminal
config, and no private SSH or GitHub auth state. Clone it, run one script,
and get a fully configured shell, editor, and toolchain for any user.

## What This Manages

| Concern | Source of truth | Applied by |
| --- | --- | --- |
| Ubuntu CLI and service packages | `setup/apt-packages.txt` | `apt-get install` |
| Node runtime | `fnm` from `setup/install-tools.sh` | `fnm install --lts` |
| Neovim, bun, pnpm, Rust, uv | `setup/install-tools.sh` | guarded installers |
| Developer CLIs | `setup/tools/*.txt` | npm, bun, cargo, go |
| Script-installed CLIs | `setup/tools/installers.sh` | guarded installers |
| Dotfiles | `home/*` stow packages | GNU Stow |
| Docker service | `apply.sh` | `systemctl enable --now docker` |

## Fresh Server Setup

If you are setting up a new Linux user, create and test it first (replace
`<username>` with the account you want):

```bash
sudo adduser <username>
sudo usermod -aG sudo <username>
sudo mkdir -p /home/<username>/.ssh
sudo cp ~/.ssh/authorized_keys /home/<username>/.ssh/authorized_keys
sudo chown -R <username>:<username> /home/<username>/.ssh
sudo chmod 700 /home/<username>/.ssh
sudo chmod 600 /home/<username>/.ssh/authorized_keys
```

Then sign in as that user and run:

```bash
git clone https://github.com/VimukthiShohan/ubuntu-server-dotfiles.git ~/.dotfiles
cd ~/.dotfiles
chmod +x setup.sh apply.sh doctor.sh setup/install-tools.sh setup/tools/installers.sh
./setup.sh
```

After `apply.sh` adds your user to the `docker` group, log out and back in
before using Docker without `sudo`.

## Git Identity

The stowed `.gitconfig` contains no personal identity. Put yours in
`~/.gitconfig.local` (it is included automatically and never committed):

```bash
git config --file ~/.gitconfig.local user.name "Your Name"
git config --file ~/.gitconfig.local user.email "you@example.com"
```

## Routine Sync

```bash
cd ~/.dotfiles
git pull
./doctor.sh
./apply.sh
```

`setup.sh` is for a fresh Ubuntu machine. `apply.sh` is safe to re-run whenever
you change package manifests or dotfiles.

## Troubleshooting

**Shell aliases missing after setup** (`y: command not found`, plain zsh prompt
instead of powerlevel10k, still landing in bash): the first `setup.sh` run
aborted partway — tools got installed, but the run died before finishing, so
your shell never picked up the config. `apply.sh` now stows dotfiles early and
tolerates clone flakes, but any step can still fail (network, sudo timeout).

Diagnose and recover:

```bash
ls -la ~/.zshenv ~/.config/zsh   # missing → dotfiles were never linked
cd ~/.dotfiles
./doctor.sh                      # read-only: lists everything that drifted
./apply.sh --fresh               # re-converge; idempotent, safe to repeat
exec zsh -l
```

`apply.sh` is a converge script: whatever failed, fixing the cause and
re-running it is always the answer. If it aborts, the failing step is the one
right above the `!! apply.sh: step above failed` line.

Note that `y` is not a binary — it is a zsh wrapper around `yazi` defined in
`50-tools.zsh`, and it only exists once the zsh config is linked and `yazi`
(built from source by the `yazi-build` crate, which can take a while) is on
`PATH`.

## Package Manifests

Ubuntu packages live in `setup/apt-packages.txt`. Keep it to CLI tools,
services, and build dependencies.

Language and tool manifests:

| File | Installed with |
| --- | --- |
| `setup/tools/npm.txt` | `npm install -g` |
| `setup/tools/bun.txt` | `bun add -g` |
| `setup/tools/cargo.txt` | `cargo install` |
| `setup/tools/go.txt` | `go install` |
| `setup/tools/installers.sh` | guarded shell installers |

Node is managed by `fnm`, not `nvm`.

## Notable Tools

Highlights installed by the manifests that have no stow package of their own:

| Tool | Installed by | Notes |
| --- | --- | --- |
| `yazi` | `setup/tools/cargo.txt` (`yazi-build`) | Terminal file manager; the `y` wrapper in `50-tools.zsh` cd's to the last visited dir on exit |
| `rtk` | `setup/tools/cargo.txt` | Token-optimized CLI proxy for AI agent sessions |
| `gum` | `setup/tools/go.txt` | Prompts and styled output for shell scripts |
| `claude`, `opencode` | `setup/tools/installers.sh` | AI coding agents (official install scripts) |
| `codex`, `portless` | `setup/tools/npm.txt` | OpenAI Codex CLI; local-dev port/domain manager |
| `aws` | `setup/tools/installers.sh` | AWS CLI v2 (`awscli` is not on Ubuntu 24.04 apt) |
| `lua-language-server` | `setup/tools/installers.sh` | Lua LSP for Neovim (not on Ubuntu 24.04 apt) |
| Neovim | `setup/install-tools.sh` | Official release tarball → `~/.local/bin/nvim`; apt's 0.9 is too old |
| bun, pnpm, Rust, uv | `setup/install-tools.sh` | Language toolchains (pnpm via corepack) |
| `zoxide`, `direnv`, `thefuck` | `setup/apt-packages.txt` | Hooked into zsh via `50-tools.zsh`: smarter `cd`, per-dir env, command corrector (aliased `fk`) |
| `just`, `ncdu`, `shellcheck` | `setup/apt-packages.txt` | Task runner, disk-usage explorer, shell linter |

## Included Stow Packages

| Package | Target | Purpose |
| --- | --- | --- |
| `zsh` | `~/.zshrc`, `~/.config/zsh/` | Shell env, aliases, `fnm`, `direnv`, `fzf`, prompt |
| `git` | `~/.gitconfig`, `~/.config/git/ignore` | Git defaults and delta pager |
| `tmux` | `~/.tmux.conf` | Tmux prefix, mouse, TPM plugins |
| `nvim` | `~/.config/nvim/` | Neovim config |
| `nvim-nightly` | `~/.config/nvim-nightly/` | Alternate Neovim config |
| `gh` | `~/.config/gh/config.yml` | GitHub CLI preferences only |
| `lazygit` | `~/.config/lazygit/config.yml` | LazyGit pager config |
| `eza` | `~/.config/eza/theme.yml` | `eza` theme |
| `btop` | `~/.config/btop/btop.conf` | `btop` config |
| `neofetch` | `~/.config/neofetch/config.conf` | Optional terminal system summary |

This repo does not stow SSH private keys, GitHub host auth, desktop app
settings, or machine-local secrets. Put machine-only secrets in untracked
local files (`~/.gitconfig.local`, `~/.config/zsh/local.zsh`).

## Verification

Run the static guard before committing changes:

```bash
bash tests/ubuntu-config.bash
bash -n setup.sh apply.sh doctor.sh setup/install-tools.sh setup/tools/installers.sh tests/ubuntu-config.bash
zsh -n home/zsh/.zshrc home/zsh/.config/zsh/*.zsh
```

## Notes For Agents

- Keep this repo Ubuntu-only and headless.
- Prefer apt packages for base CLI/service tools.
- Keep desktop apps and platform UI settings out of this repo.
- Do not commit SSH keys, GitHub auth hosts, tokens, or machine-local secrets.
- Change the manifest first, then run `apply.sh`.
