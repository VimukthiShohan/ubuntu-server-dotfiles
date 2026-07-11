# AGENTS.md

This file provides shared guidance to AI coding agents when working with code in this repository.

## Project Overview

Ubuntu 24.04 **server** dotfiles: a headless CLI/service development environment applied with GNU
Stow plus idempotent bash scripts. Intentionally no desktop apps, no GUI terminal config, and no
SSH/GitHub auth state. `README.md` is the canonical human-facing doc (setup walkthrough, stow
package table, mobile-CLI notes) — don't duplicate its tables here.

## Repository Layout

```
setup.sh                 ← fresh-Ubuntu bootstrap: prereqs via apt, then apply.sh --fresh
apply.sh                 ← idempotent converge: apt manifest → bat/fd shims → install-tools.sh
                            → docker service → zsh login shell → clone fzf-git/tpm/p10k
                            → stow home/* → tmux config reload
doctor.sh                ← read-only drift/status checks (exits 1 on issues); never mutates
setup/
  apt-packages.txt       ← apt manifest (one package per line, # comments ignored)
  install-tools.sh       ← bootstraps Neovim (official tarball), fnm/node, bun, pnpm, rust, uv;
                            then installs the tools/ manifests
  tools/
    npm.txt · bun.txt · cargo.txt · go.txt   ← per-package-manager manifests
    installers.sh        ← guarded curl installers (aws-cli, lua-language-server, zsh-completions)
home/                    ← GNU Stow packages (one dir per tool) linked into $HOME:
                            zsh · git · tmux · nvim · nvim-nightly · gh · lazygit · eza ·
                            btop · neofetch
scripts/
  tmx/                   ← tmux dev-workspace bootstrapper (main.sh + lib/ + config/, `tmx` alias)
  switch_nvim_config.sh  ← swap ~/.config/nvim between stable and nightly configs
  migrate-to-stow.sh     ← one-time migration helper
tests/ubuntu-config.bash ← static guard: forbidden/required patterns (see Hard Constraints)
.stowrc                  ← --dir=home --target=~ plus ignore patterns
```

## Workflow

Change the manifest or dotfile first, then converge:

```
edit manifest/dotfile → bash tests/ubuntu-config.bash → ./apply.sh
```

- Fresh machine → `./setup.sh` · re-converge → `./apply.sh` (`--fresh` = `stow --adopt`) ·
  inspect drift → `./doctor.sh`
- New apt package → `setup/apt-packages.txt` · new dev CLI → the matching `setup/tools/*.txt`
  (or `installers.sh` if curl-installed) · new dotfile → `home/<pkg>/` mirroring its `$HOME` path
- Never hand-install on a machine and call it done — if it isn't in a manifest or stow package,
  it doesn't exist.

## Verification (run before committing)

```bash
bash tests/ubuntu-config.bash
bash -n setup.sh apply.sh doctor.sh setup/install-tools.sh setup/tools/installers.sh tests/ubuntu-config.bash
zsh -n home/zsh/.zshrc home/zsh/.config/zsh/*.zsh
```

## Hard Constraints

Most are gated by `tests/ubuntu-config.bash` — a violation fails the guard.

- **Ubuntu-only, headless.** No macOS artifacts (brew/cask/mas, Ghostty, Zed, yabai, skhd,
  `/opt/homebrew`, `pbcopy`, `Library/…` paths), no desktop apps or platform UI settings.
- **No secrets in the repo.** Never commit SSH keys, `gh` `hosts.yml`, tokens, or machine-local
  state. Machine-only config goes in untracked files: `~/.gitconfig.local`,
  `~/.config/zsh/local.zsh` (sourced by `90-local.zsh`).
- **Node via `fnm`, never `nvm`** (guard rejects any `nvm` reference in `setup/` or `home/zsh`).
  pnpm via corepack; `PNPM_HOME=$HOME/.local/share/pnpm`.
- **Neovim from the official release tarball**, symlinked to `~/.local/bin/nvim` — never the apt
  `neovim` package (Noble ships 0.9). Version-sensitive Neovim options (e.g. `vim.opt.winborder`)
  must stay `pcall`-guarded in `home/nvim/.config/nvim/lua/config/set.lua`.
- **apt manifest hygiene:** no `lua-language-server`/`awscli` (unavailable on 24.04 — they live in
  `installers.sh`), no Ruby/rbenv, keep `thefuck`.
- **cargo manifest:** installs use `cargo install --locked`; yazi ships as `yazi-build` (not
  `yazi-fm`/`yazi-cli`); `rtk` must stay listed.
- **zsh layout:** `ZDOTDIR=~/.config/zsh` set in `home/zsh/.zshenv`; config is split into numbered
  files `00-env` → `90-local` — put new settings in the matching slot.
- **Script discipline:** `apply.sh`/`install-tools.sh` stay idempotent and safe to re-run;
  `doctor.sh` stays strictly read-only; manifest readers ignore blank lines and `#` comments —
  keep that format.

## Commit Convention

Concise, imperative, lowercase subject lines describing the change (matching the existing history:
`update default realm names in Keycloak cloning script`). Single `main` branch, no tags or releases,
no commitlint/husky tooling in this repo.

Types: feat, fix, docs, refactor, test, chore, perf, ci. Branch patterns:`feat/`, `fix/`, `hotfix/`, `docs/`, `chore/`, `refactor/`.

**Commit generation rules (Claude Code):**

- The user generates every commit by running `/pc:commit` manually. Do not run `git commit` yourself — stage changes only and hand off.
- Never add `Co-Authored-By: Claude` (or any AI co-author trailer) to commit messages.
- Keep the subject line ≤ **100** characters, with a blank line before any body; wrap body lines at 100 too.

## Response Style

Draw it, don't narrate it. Lead with the answer. Prefer the tightest exact form: compare ⇒ table ·
hierarchy ⇒ indented tree · short flow ⇒ `A → B → C` (one line max, else numbered steps) · decision ⇒
`if X → P · else → Q` · one fact ⇒ one line. Cut filler ("just", "basically", hedging, pleasantries);
never restate the question; keep every identifier/path/number/command exact — compression never costs
precision. Drop to prose only for security warnings, irreversible-action confirmations, genuinely
complex trade-off discussion, or when the user asks you to expand.
