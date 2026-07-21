# Bootstrap Profiles — Design Spec

**Date:** 2026-07-20
**Status:** Approved for planning (amended after cross-AI review — see "Review amendments")

## Goal

The fresh-machine one-liner (`bootstrap.sh` → `setup.sh`) currently installs everything. Add
profile selection so a user can converge a machine as:

1. **minimal** — essentials for any server
2. **developer** — everything the repo installs today (minimal + editor stack + runtimes + AI CLIs)
3. **custom** — essentials + user-picked groups

When the developer profile is chosen, or the custom selection includes the AI-CLIs group, offer an
optional AI-skills installation step (SuperClaude, Superpowers, mattpocock/skills, Graphify, plus
claude-code-only skills).

Before any of that, `bootstrap.sh` optionally creates a fresh server user and hands the whole
install off to that account (see "New-user step").

The bootstrap one-liner itself does not change:

```bash
f=$(mktemp) && curl -fsSL https://raw.githubusercontent.com/VimukthiShohan/ubuntu-server-dotfiles/main/bootstrap.sh -o "$f" && bash "$f"
```

## Groups

Groups are the unit everything keys on. Each group spans four layers: apt packages, curl-installed
runtimes/installers, package-manager manifests, and stow packages.

| Group | apt | runtimes / installers | manifests | stow |
|---|---|---|---|---|
| **core** *(always active)* | sudo, ca-certificates, software-properties-common, curl, wget, git, zsh, stow, tmux, less, jq, tree, unzip, zip, rsync, htop, ncurses-term | zsh-completions | — | zsh, git, tmux, dotf |
| ergonomics | ripgrep, fd-find, fzf, bat, eza, git-delta, zoxide, btop, ncdu, direnv, just, thefuck, telnet, shellcheck, gh | — | — | eza, btop, neofetch, gh, git-dev |
| build | build-essential, pkg-config, cmake, ninja-build, gettext, libssl-dev, libreadline-dev, zlib1g-dev, libsqlite3-dev, libbz2-dev, libffi-dev, liblzma-dev | — | — | — |
| services | docker.io, docker-compose-v2, postgresql-client, redis-tools | — | — | — |
| nvim *(deps: build, node)* | luarocks | Neovim tarball, lua-language-server | npm: tree-sitter-cli | nvim, nvim-nightly |
| node | — | fnm+node, bun, pnpm | npm: typescript, portless; bun.txt | — |
| rust *(dep: build)* | — | rustup | cargo: yazi-build, rtk | — |
| go-tools | golang-go | — | go: gum, lazygit | lazygit |
| python | python3-pip, python3-venv, pipx | uv | — | — |
| ai-clis *(dep: node)* | — | claude code, opencode | npm: @openai/codex | — |
| cloud | — | aws-cli | — | — |
| media | imagemagick, poppler-utils | — | — | — |

Profile composition:

- **minimal** = core only
- **developer** = all groups
- **custom** = core + user-picked groups plus their dependency closure

**Single group registry.** Group names, their dependencies, and their stow-package mapping are
defined once in a shared library (`setup/lib/profile.sh`) sourced by every script. Dependency
closure is recomputed from this registry on **every state load**, not only at selection time — if
a later repo version adds a dependency, existing machines pick it up on the next converge (with a
printed notice). Read-write contexts persist the expanded set back; read-only contexts expand in
memory only.

**Minimal must leave a working shell.** Core-stowed configs may not hard-depend on other groups'
binaries:

- zsh aliases for optional tools become guarded:
  `command -v eza >/dev/null && alias ls='eza'` (same for `cat`→`bat`, `vim`→`nvim`,
  `lg`→`lazygit`, etc.). Same guard for `EDITOR`-style env vars that point at nvim.
- `home/git/.gitconfig` (core) keeps vanilla pager/editor and gains
  `[include] path = ~/.config/git/dev.gitconfig`. The delta pager, `editor = nvim`,
  `diffFilter`, and nvim merge/difftool settings move to a new stow package **git-dev**
  (`home/git-dev/.config/git/dev.gitconfig`), mapped to the ergonomics group. Git silently
  ignores a missing include, so minimal needs no runtime logic.

Existing behaviors folded into groups:

- The bat/fd shim step in `apply.sh` stays unconditional but is already guarded by
  `command -v batcat`/`fdfind`, so it is a natural no-op when the ergonomics group (which owns the
  bat and fd-find apt entries) is inactive.
- Docker service enablement in `apply.sh` runs only when the services group is active.
- fzf-git / tpm / p10k clones stay core (they back the stowed zsh/tmux config).
- `scripts/` (tmx etc.) is not stowed and is unaffected.

## Manifest format

Keep one manifest file per package manager (single source of truth). Add group section headers that
readers filter on:

```
## group: core
sudo
ca-certificates
...

## group: ergonomics
ripgrep
...
```

Rules:

- Header syntax: `## group: <name>` (exact prefix `## group:`), where `<name>` is one of the known
  group names.
- Every package line must appear below a group header. A package line before any header is a guard
  failure.
- Blank lines and `#` comments remain ignored as today; `## group:` is parsed before the generic
  comment rule.
- Applies to `setup/apt-packages.txt`, `setup/tools/npm.txt`, `setup/tools/bun.txt`,
  `setup/tools/cargo.txt`, `setup/tools/go.txt`. Files whose entries all belong to one group (e.g.
  `cargo.txt` → rust) still carry the header for uniformity.

## State file

`~/.config/dotf/profile` (respecting `$XDG_CONFIG_HOME`, default `~/.config`). **Outside the
repo** — bootstrap's `git status --porcelain --ignored` dirty check never sees it, and a
relocated clone (`DOTFILES_DIR`) cannot orphan it. No `.gitignore` change needed.

```
DOTF_PROFILE=custom
DOTF_GROUPS=ergonomics,services
DOTF_SKILLS=superpowers,superclaude
```

- `DOTF_` prefix throughout (bare `GROUPS` is a reserved bash array variable).
- `DOTF_GROUPS`: picked groups for custom (excluding core, including the dependency closure).
  Minimal → empty; developer → full group list written out explicitly.
- `DOTF_SKILLS`: comma-separated selected skill slugs; the literal value `none` means "asked and
  declined"; an **absent key** means "never asked" (see Skills step).
- **Never sourced.** The file is data, not shell: a single loader in `setup/lib/profile.sh`
  parses it with a strict `^DOTF_[A-Z_]+=[a-z0-9,_-]*$` grammar and an allowlisted key set.
  Unknown keys, duplicate keys, or malformed lines fail validation.
- **Atomic writes:** written to a temp file in the same directory, then `mv`'d into place.
- **Validation on load:**
  - Missing file → interactive read-write context prompts and writes; any read-only context
    falls back to **developer** with a printed warning suggesting `dotf profile` (preserves
    current behavior for existing machines; doctor additionally reports the fallback).
  - Malformed file, unknown profile, or unknown group name → hard error naming
    `dotf profile` — except in `setup.sh`/`dotf profile` themselves, which warn, re-prompt, and
    rewrite (so recovery is always possible).

### Loader modes

| Mode | Scripts | Missing file | Invalid file |
|---|---|---|---|
| read-write | `setup.sh`, `dotf profile`, `dotf skills` | prompt (or developer default when non-interactive) → write | warn → re-prompt → rewrite |
| read-only | `apply.sh`, `install-tools.sh`, `tools/installers.sh`, `doctor.sh`, direct script runs | developer fallback + warning; never writes | hard error → "run dotf profile" |

## New-user step (`bootstrap.sh`)

Runs at the top of `bootstrap.sh`, after the Ubuntu gate and git check, before the clone.
Skipped entirely when `DOTF_BOOTSTRAP_HANDOFF=1` is set (the re-exec guard) or when no `/dev/tty`
is available.

```
prompt (/dev/tty): "Create a new user for this setup? [y/N]"
  no  → continue as the current user (flow unchanged)
  yes → read username
        invalid (fails ^[a-z_][a-z0-9_-]*$) → re-ask
        username already exists (getent passwd) → explain and re-ask
                                                  (no install-for-existing-user path)
        sudo adduser <username>  </dev/tty >/dev/tty 2>&1   (interactive password + GECOS)
        sudo usermod -aG sudo <username>
        ~/.ssh/authorized_keys exists on the bootstrap account?
          yes → hardened copy (below)
          no  → warn "no authorized_keys to copy — set up SSH access manually"; continue
        DOTF_BOOTSTRAP_HANDOFF=1 sudo -u <username> -H bash <script-copy>
        exit $?        ← parent stops here; nothing runs for the original account
```

Hardened `authorized_keys` copy — never follow or overwrite through symlinks:

```
home="$(getent passwd <username> | cut -d: -f6)"    # not assumed to be /home/<username>
group="$(id -gn <username>)"                        # not assumed to equal the username
sudo install -d -m 700 -o <username> -g "$group" "$home/.ssh"
[ -L "$home/.ssh" ] || [ -L "$home/.ssh/authorized_keys" ] → abort the copy with a warning
sudo install -m 600 -o <username> -g "$group" ~/.ssh/authorized_keys "$home/.ssh/authorized_keys"
```

(For a *freshly created* user the home is empty, so the symlink checks are belt-and-braces; they
make the block safe even if the flow ever changes. `install` writes the destination directly and
does not traverse a symlinked final component the way `cp` does; the explicit `-L` checks reject
the remaining cases.)

Rules:

- **Handoff is total and terminal.** The parent `exit`s immediately after `sudo -u` returns,
  propagating the child's status. The re-exec'd copy runs with `DOTF_BOOTSTRAP_HANDOFF=1`, so it
  can never prompt to create another user (no recursion). The clone lands in
  `/home/<username>/.dotfiles` and every later prompt (profile, skills) runs as the new user. The
  original bootstrap account gets nothing installed.
- **Prompts and `adduser` read `/dev/tty` explicitly** — `bootstrap.sh` runs `exec </dev/null`
  (line ~106), so anything left reading stdin sees EOF.
- The script copy passed to `sudo -u` must be readable by the new user (the mktemp download is
  0600 to the original user) — copy it to a new-user-readable path first.
- Existing accounts are **never reused**: the only outcomes are create-fresh or re-ask. This
  removes every assumption about existing homes, primary groups, locked passwords, and system
  accounts — and never grants sudo to a pre-existing account.
- `adduser` failure → abort bootstrap with the error visible (nothing has been cloned yet).
- `sudo` during the re-exec'd install authenticates as the new user with the password just set,
  prompted on `/dev/tty`.
- Non-interactive (no `/dev/tty`) → skip the step entirely; current behavior.
- Password handling stays interactive `adduser` — no `--disabled-password`, no NOPASSWD sudoers
  entries.

## Flow

```
bootstrap.sh ([new-user step] → clone) → setup.sh → [prompt if no state file] → write state
  → apply.sh --fresh (reads state) → apt (filtered) → stow (group-mapped)
  → install-tools.sh (runtimes per group → installers.sh → manifests, all filtered)
  → docker service (services group) → zsh login shell → repo clones → tmux reload
  → skills.sh — only after install-tools.sh has fully completed (manifests included),
    so npm-installed CLIs like @openai/codex exist before any skill installer probes for them
```

- **Prompting:** `setup.sh` prompts via `/dev/tty` (not stdin) when the state file does not
  exist. Profile menu is a numbered choice (1 minimal / 2 developer / 3 custom). Custom shows a
  numbered group list (core marked "always included") and reads comma-separated numbers.
- **Re-runs never re-ask:** converge/check scripts use the read-only loader (see table above).
- **Stow:** `apply.sh` stows only the packages mapped to active groups. It does not unstow
  packages for deactivated groups automatically; `dotf profile` handles transitions (see below).

## Skills step

New `setup/skills.sh`:

- Runs when the developer profile is active or the custom selection includes ai-clis, **after**
  `install-tools.sh` has finished entirely.
- `DOTF_SKILLS` semantics:
  - key absent → never asked. Interactive → prompt now; non-interactive → install nothing and
    leave the key absent, so a later interactive run still asks.
  - `DOTF_SKILLS=none` → asked and declined; never re-prompt (change via `dotf skills`).
  - otherwise → install exactly the listed slugs, no re-prompt.
- Prompt (via `/dev/tty`) is a multi-select of:
  - SuperClaude Framework — <https://github.com/SuperClaude-Org/SuperClaude_Framework>
  - Superpowers — <https://github.com/obra/Superpowers>
  - mattpocock/skills — <https://github.com/mattpocock/skills>
  - Graphify — <https://github.com/Graphify-Labs/graphify>
  - *(shown only when the `claude` binary is installed)* react-devtools (callstack) —
    <https://claudemarketplaces.com/skills/callstackincubator/agent-react-devtools/react-devtools>
  - *(shown only when the `claude` binary is installed)* callstack agent-skills —
    <https://github.com/callstackincubator/agent-skills>
- **Idempotency by re-run, not presence-skip:** each installer block re-runs its official
  install/update command every time (they are expected to be idempotent upgrades). A bare
  "directory exists → skip" guard is forbidden — it would permanently mask a partially-completed
  install. Where an installer is expensive, the guard must be a health check (the framework's own
  version/doctor command exiting 0), not mere existence.
- Failures are collected `FAILURES+=()`-style and reported, never fatal, matching
  `install-tools.sh` conventions.
- **Exact install commands are NOT specified here** — they must be verified against each repo's
  current README during implementation planning, not recalled from memory.

## dotf subcommands

- `dotf profile` — re-run the profile/group selection, rewrite the state file, then run
  `apply.sh`. When groups were removed, print which stow packages/tools are now orphaned and how
  to remove them — do not remove automatically. (The guard test's dotf pattern must be narrowed
  so mentioning removal commands in *output strings* is allowed while invoking them is still
  rejected — see Guard test.)
- `dotf skills` — re-run the skills selection, rewrite `DOTF_SKILLS`, run `setup/skills.sh`.

## doctor.sh

Uses the read-only loader; checks only active groups' packages, binaries, and stow links.
Reports the active profile/groups (or the developer fallback) in its header. Stays strictly
read-only — the loader parses rather than sources, so no state-file content can execute.

## Guard test (`tests/ubuntu-config.bash`)

- Parse the new section format; existing forbidden/required package rules keep working.
- New rules: every manifest package line sits under a `## group:` header; every header names a
  group defined in `setup/lib/profile.sh`; `rtk` stays in cargo manifest; existing constraints
  (no nvm, no apt lua-language-server/awscli/tree-sitter-cli, etc.) unchanged.
- **Narrow the dotf pattern** (currently `apt-get|stow -|sudo ` anywhere in the file): match
  only actual command invocations (line-start/pipe/`&&` positions), so `dotf profile` may *print*
  `stow -D` guidance without failing the guard.
- **Function-level tests** for the new pure-bash logic, runnable anywhere without apt:
  `setup/lib/profile.sh` is sourced by the guard test and exercised with fixtures — state-file
  parse/validate (valid, malformed, unknown key, unknown group, duplicate key, empty), dependency
  closure (including a registry-gains-a-dep migration case), and manifest group filtering
  (packages before headers, unknown group headers, comment/blank handling).
- `bash -n` list gains `setup/skills.sh` and `setup/lib/profile.sh`.

## Error handling

- Prompt input validation: re-ask on invalid choice (bad number, unknown group index).
- New-user step: empty/invalid username → re-ask; existing username → re-ask; `adduser` failure →
  abort bootstrap with the error visible (nothing has been cloned yet).
- `/dev/tty` unavailable mid-prompt → fall back to developer default with a printed warning.
- State file errors per the Loader modes table: missing → prompt or developer fallback;
  malformed/unknown-group → re-prompt in read-write contexts, hard error in read-only contexts.
- Skills installers follow the `FAILURES+=()` collect-and-report pattern — a failed skill install
  never aborts the run.

## Testing

- `tests/ubuntu-config.bash` covers manifest structure statically **and** unit-tests
  `setup/lib/profile.sh` (parser, validator, dependency closure, manifest filter) with fixtures —
  the highest-risk pure logic is exercised on every run, everywhere.
- New-user step: the interactive/system-mutating parts (`adduser`, key copy, handoff re-exec)
  cannot run in the static guard; they are verified in the fresh-VM matrix below. Their
  non-mutating validation logic (username regex, symlink rejection) lives in testable functions
  covered by the guard test.
- End-to-end profile flows are verified manually on a fresh Ubuntu 24.04 container/VM:
  minimal / developer / custom+deps, each with and without the new-user step, plus a re-run of
  bootstrap after a completed install (idempotency + no re-prompt) and a run with a
  deliberately corrupted state file (expect the hard error, then `dotf profile` recovery).

## Review amendments

Amended 2026-07-20 after an independent cross-AI review (codex / gpt-5.6-sol, xhigh): hardened
new-user key copy and removed the existing-user reuse path; moved state to `~/.config/dotf/profile`
(out of the repo, fixing bootstrap's ignored-files dirty check and `DOTFILES_DIR`); state file
parsed not sourced, written atomically, validated on load with explicit read-write/read-only loader
modes; `DOTF_SKILLS=none` sentinel; dependency closure recomputed every load from a single
registry; guarded aliases + git include split so minimal keeps a working shell; `adduser` wired to
`/dev/tty` (bootstrap detaches stdin); handoff made one-shot and terminal; skills installers re-run
instead of presence-skip and run after all manifests; dotf guard narrowed; function-level tests
added for the new pure-bash logic.

## Out of scope

- Uninstalling packages when switching to a smaller profile (reported, not performed).
- macOS or non-Ubuntu support (unchanged repo constraint).
- Per-package (rather than per-group) custom selection.
