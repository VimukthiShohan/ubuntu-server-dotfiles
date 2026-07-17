# dotf CLI — design spec

Date: 2026-07-12
Status: approved (brainstorm complete, pending implementation)
Target release: **v2.0.0** (tag + GitHub release, after all tasks land on `main`; current release is v1.1.1)

## Goal

One command for both lifecycle moments of this repo:

- **Fresh Ubuntu server** — a single curl one-liner bootstraps the whole environment.
- **Daily use** — `dotf <subcommand>` replaces remembering `./apply.sh`, `./doctor.sh`, and the
  verification block, from any working directory.

Non-goals (YAGNI, explicitly out of scope): manifest helpers (`dotf add apt <pkg>`), stow package
management (`dotf link/unlink/new`), npm/cargo/go packaging, publishing for third parties, fixing
the hardcoded `~/.dotfiles` path in the tmx alias (`home/zsh/.config/zsh/30-aliases.zsh` — decided
out of scope during grilling).
Existing `setup.sh` / `apply.sh` / `doctor.sh` remain untouched and directly runnable — `dotf` is
a veneer, not a migration.

## Decisions made during brainstorm

| fork | decision | why |
|---|---|---|
| Packaging | Bash CLI in this repo | Fresh servers have no node/rust; zero new runtime deps; matches repo idiom |
| Scope | Wrapper + update | Thin layer over working scripts; smallest surface |
| Name | `dotf` | `dot` belongs to Graphviz (collision risk if ever installed); 4 keys, unambiguous |
| Structure | Single-file script | 5 delegating subcommands don't justify a `lib/` split (`tmx` earned its split at ~10× the logic) |
| Bootstrap clone | HTTPS, not SSH | Repo is public; repo constraint forbids baked-in auth state |
| Clone location | `~/.dotfiles` | Codebase already assumes it (tmx alias, `.stowrc` comment) — spec originally said `~/dotfiles`, corrected during grilling |
| Bootstrap user | Non-root sudo user | Matches setup.sh's existing `sudo` assumptions; "create a sudo user first" documented as a README precondition (root-without-sudo VPS images not handled) |
| Existing clone dir | Verify origin, then proceed | Re-runs are safe; a foreign directory at the target path aborts instead of executing its scripts |
| Release version | v2.0.0 | User's call. The changes are additive (strict semver would say v1.1.0) — nothing in v1.0.0 breaks; v2 marks the repo's shift from script-collection to CLI-driven tool |

## Components

```
bootstrap.sh                   ← new, repo root: curl target for fresh machines
home/dotf/.local/bin/dotf      ← new stow package: the CLI (single bash file, executable)
```

## dotf CLI

### Repo discovery (zero config)

Stow links `~/.local/bin/dotf` → `home/dotf/.local/bin/dotf` inside the repo.
`readlink -f "$0"` resolves the symlink to the real file; the repo root is five `dirname` steps up
(`…/home/dotf/.local/bin/dotf` is a file, so the first `dirname` strips it before any directory →
strip `dotf` (file), `bin`, `.local`, `dotf`, `home`).
Works wherever the repo is cloned (`~/.dotfiles` on servers, `~/Projects/Private/dotfiles` on the
authoring machine). If the resolved path does not look like the repo (no `apply.sh` at the derived
root), fail with a clear error instead of guessing.

### Subcommands

| command | behaviour |
|---|---|
| `dotf apply [--fresh]` | exec `apply.sh` (flags passed through) |
| `dotf doctor` | exec `doctor.sh` — read-only, exits 1 on drift |
| `dotf update` | `git pull --ff-only` in the repo, then `apply.sh`; refuses if there are tracked (committed-file) modifications — untracked files are allowed |
| `dotf test` | the pre-commit verification block: `bash tests/ubuntu-config.bash`, `bash -n` over all repo scripts (including `bootstrap.sh` and `dotf` itself), `zsh -n home/zsh/.zshrc home/zsh/.config/zsh/*.zsh` |
| `dotf help`, no args, `-h`, `--help` | usage, exit 0 |
| unknown subcommand | usage on stderr, exit 1 |

### Error handling

- `set -euo pipefail` throughout.
- `update` aborts with a message if there are tracked modifications
  (`git status --porcelain --untracked-files=no` non-empty), or if the pull is not a fast-forward.
  Untracked files do not block the update.
- Repo-root discovery failure → explicit error naming the resolved path.

## bootstrap.sh

Curl target:

```
curl -fsSL https://raw.githubusercontent.com/VimukthiShohan/ubuntu-server-dotfiles/main/bootstrap.sh | bash
```

Precondition (documented in README): run as a non-root user with sudo — same assumption
`setup.sh` already makes.

Flow (idempotent, safe to re-run):

1. Ubuntu check (same `/etc/os-release` gate as `setup.sh`).
2. `sudo apt-get install -y git` only if git is missing.
3. Clone `https://github.com/VimukthiShohan/ubuntu-server-dotfiles.git` to `~/.dotfiles`
   (override with `DOTFILES_DIR` env var). If the target dir already exists, proceed only when it
   passes full upstream verification: origin normalizes exactly to the HTTPS `REPO_HTTPS` constant
   (SSH-form origins are rejected — the clone is always HTTPS), `git fetch origin main` succeeds,
   the tree is clean (`status --porcelain --ignored` empty), and `HEAD == FETCH_HEAD`. Any failure
   aborts with a clear message naming the directory. All verification git commands run with
   config-driven code execution neutralized (`GIT_CONFIG_NOSYSTEM`, empty
   fsmonitor/hooks/credential/ssh helpers) so a planted `.git/config` cannot execute before the
   clone is trusted.
4. Run `<dir>/setup.sh` (which delegates to `apply.sh --fresh`; the stow step is what installs
   `dotf` into `~/.local/bin`).
5. Final message: start a new login shell (shell change + PATH) — `dotf` is available from then on.

- `set -euo pipefail`; clear failure trap mirroring `setup.sh`'s.
- Piped-execution hardening: whole script is functions with a trailing `main "$@"` (nothing
  executes until fully parsed), and `main` redirects stdin from `/dev/null` so no inner command
  can consume script text streamed via `curl | bash`.
- HTTPS clone only — no SSH, no tokens, no `gh` dependency (repo constraint: no auth state).

## Integration with existing files

- `apply.sh` — `home/dotf` is picked up by the existing `stow home/*` loop. Small supporting
  changes landed during hardening: `mkdir -p "$HOME/.local/bin"` before stow (so `dotf` links as a
  file, not a folded dir-symlink), `-E` on `set` so the ERR trap fires inside functions, argument
  validation (only `--fresh` accepted), and post-install repo-clone failures warn + `exit 0`
  (network flake is non-fatal; re-running retries) rather than aborting the whole converge.
- `doctor.sh` — add a check that `~/.local/bin/dotf` resolves into the repo (drift signal).
- `tests/ubuntu-config.bash` — new guards: `bootstrap.sh` must use the HTTPS clone URL (reject
  `git@`/`ssh://`); existing forbidden-pattern sweeps (macOS artifacts, nvm) apply to the new
  files automatically where the test globs cover them — extend globs if needed.
- `README.md` — add the bootstrap one-liner (with the non-root-sudo-user precondition) and a
  short `dotf` subcommand table.
- `AGENTS.md` — add `bootstrap.sh` and `home/dotf/.local/bin/dotf` to the repo-layout tree and the
  `bash -n` verification list; note `dotf test` as the shorthand.

## Testing

- `dotf test` passes on the authoring machine.
- `bash -n bootstrap.sh home/dotf/.local/bin/dotf` clean.
- Manual: `dotf doctor` and `dotf apply` from a directory outside the repo; `dotf update` refusal
  on a dirty tree; unknown-subcommand exit code.
- Bootstrap end-to-end is verified on the next fresh server provision (no local VM harness in
  this repo — accepted gap, noted here deliberately).
