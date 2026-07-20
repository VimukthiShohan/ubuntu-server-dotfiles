# AGENTS.md

This file provides shared guidance to AI coding agents when working with code in this repository.

## Project Overview

Ubuntu 24.04 **server** dotfiles: a headless CLI/service development environment applied with GNU
Stow plus idempotent bash scripts. Intentionally no desktop apps, no GUI terminal config, and no
SSH/GitHub auth state. `README.md` is the canonical human-facing doc (setup walkthrough, stow
package table) — don't duplicate its tables here.

## Repository Layout

```
setup.sh                 ← fresh-Ubuntu bootstrap: prereqs via apt, then apply.sh --fresh
apply.sh                 ← idempotent converge: apt manifest → bat/fd shims → stow home/*
                            → install-tools.sh → docker service → zsh login shell
                            → clone fzf-git/tpm/p10k (non-fatal) → tmux config reload
doctor.sh                ← read-only drift/status checks (exits 1 on issues); never mutates
bootstrap.sh             ← curl target: Ubuntu gate → git → verified HTTPS clone to ~/.dotfiles → setup.sh
setup/
  apt-packages.txt       ← apt manifest (one package per line, # comments ignored)
  install-tools.sh       ← bootstraps Neovim (official tarball), fnm/node, bun, pnpm, rust, uv;
                            then installs the tools/ manifests
  lib/profile.sh          ← profiles/groups/state-file registry; sourced by every script below
  profile-select.sh      ← interactive profile/group picker; writes the state file
  skills.sh               ← optional AI skill framework installer (SuperClaude, Superpowers, …)
  tools/
    npm.txt · bun.txt · cargo.txt · go.txt   ← per-package-manager manifests
    installers.sh        ← guarded curl installers (aws-cli, lua-language-server, zsh-completions)
home/                    ← GNU Stow packages (one dir per tool) linked into $HOME:
                            zsh · git · git-dev · tmux · nvim · nvim-nightly · gh · lazygit · eza ·
                            btop · neofetch · dotf
scripts/
  tmx/                   ← tmux dev-workspace bootstrapper (main.sh + lib/ + config/, `tmx` alias)
  switch_nvim_config.sh  ← swap ~/.config/nvim between stable and nightly configs
  migrate-to-stow.sh     ← one-time migration helper
tests/
  ubuntu-config.bash     ← static guard: forbidden/required patterns (see Hard Constraints)
  profile-lib-test.bash  ← pure-bash unit tests for setup/lib/profile.sh (parse/closure/manifest filter)
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
  — every manifest is group-sectioned (`## group: <name>` headers), so add the new line under the
  right group header, not appended blindly (guard-enforced).
- Profiles gate what actually installs: state lives at
  `${XDG_CONFIG_HOME:-$HOME/.config}/dotf/profile` (outside the repo, never committed). Change it
  with `dotf profile` (re-select profile/groups, then converge) or `dotf skills` (re-select and
  (re)install optional AI skill frameworks).
- Never hand-install on a machine and call it done — if it isn't in a manifest or stow package,
  it doesn't exist.
- Fresh machine one-liner → `f=$(mktemp) && curl -fsSL https://raw.githubusercontent.com/VimukthiShohan/ubuntu-server-dotfiles/main/bootstrap.sh -o "$f" && bash "$f"` (download-then-run, so a truncated download can't run a partial script or report false success)
- `dotf` (stowed to `~/.local/bin`) wraps the scripts: `dotf apply|doctor|update|profile|skills|test` — `dotf test` runs the verification block below.

## Verification (run before committing)

```bash
bash tests/ubuntu-config.bash
bash -n setup.sh apply.sh doctor.sh bootstrap.sh setup/install-tools.sh setup/tools/installers.sh \
  setup/lib/profile.sh setup/profile-select.sh setup/skills.sh tests/ubuntu-config.bash \
  tests/profile-lib-test.bash home/dotf/.local/bin/dotf
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
  `installers.sh`), no `tree-sitter-cli` (Noble ships 0.20.8, too old for nvim-treesitter's
  `tree-sitter build` — it lives in `setup/tools/npm.txt`), no Ruby/rbenv, keep `thefuck`.
- **cargo manifest:** installs use `cargo install --locked`; yazi ships as `yazi-build` (not
  `yazi-fm`/`yazi-cli`); `rtk` must stay listed.
- **zsh layout:** `ZDOTDIR=~/.config/zsh` set in `home/zsh/.zshenv`; config is split into numbered
  files `00-env` → `90-local` — put new settings in the matching slot.
- **Script discipline:** `apply.sh`/`install-tools.sh` stay idempotent and safe to re-run;
  `doctor.sh` stays strictly read-only; manifest readers ignore blank lines and `#` comments —
  keep that format.
- **Profiles:** the state file is parsed, never sourced — no state-file content can execute.
  Manifest lines must sit under a `## group: <name>` header naming a group known to
  `setup/lib/profile.sh` (guard-enforced).

## Commit Convention

Concise, imperative, lowercase subject lines describing the change (matching the existing history:
`update default realm names in Keycloak cloning script`). Single `main` branch, no commitlint/husky
tooling in this repo.

Types: feat, fix, docs, refactor, test, chore, perf, ci. Branch patterns:`feat/`, `fix/`, `hotfix/`, `docs/`, `chore/`, `refactor/`.

## Release Workflow

Releases are cut from `main` as annotated semver tags with a matching GitHub release
(first release: `v1.0.0`).

```bash
git tag -a vX.Y.Z -m "vX.Y.Z" <commit>
git push origin vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z" --notes "<summary of changes>" --verify-tag
```

- Tag name and release title are identical: `vX.Y.Z`.
- Tag only commits already pushed to `origin/main`; uncommitted/staged work is never part of a release.

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
