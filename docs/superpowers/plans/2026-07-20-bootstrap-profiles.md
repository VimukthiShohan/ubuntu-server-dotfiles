# Bootstrap Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Profile selection (minimal / developer / custom) for the dotfiles bootstrap, with group-tagged manifests, a validated state file, an optional new-user handoff in `bootstrap.sh`, and an optional AI-skills install step.

**Architecture:** A single pure-bash library (`setup/lib/profile.sh`) owns the group registry, state-file parse/validate/write, dependency closure, and manifest filtering; every script sources it. Interactive selection lives in `setup/profile-select.sh` (reused by `setup.sh` and `dotf profile`). Manifests gain `## group: <name>` section headers. State persists at `~/.config/dotf/profile`, parsed — never sourced.

**Tech Stack:** bash (POSIX-ish, must run under macOS bash 3.2 for the guard test — no associative arrays, no `mapfile`, no `${var,,}`), GNU Stow, apt.

**Spec:** `docs/superpowers/specs/2026-07-20-bootstrap-profiles-design.md` — read it before starting any task.

## Global Constraints

- **Never run `git commit`.** Stage with `git add` and stop; the user commits via `/pc:commit`. Never add any AI co-author trailer.
- `setup/lib/profile.sh` and `tests/profile-lib-test.bash` must run under **bash 3.2** (dev machine is macOS; `dotf test` runs there). No `declare -A`, no `mapfile`, no `${var,,}`.
- `apply.sh` / `install-tools.sh` / `installers.sh` / `skills.sh` stay idempotent and safe to re-run. `doctor.sh` stays strictly read-only.
- State file grammar: lines matching `^(DOTF_PROFILE|DOTF_GROUPS|DOTF_SKILLS)=[a-z0-9@,._/-]*$`, each key at most once. Never sourced.
- Group names (exact): `ergonomics build services nvim node rust go-tools python ai-clis cloud media` (+ implicit `core`). Deps: `nvim → build node` · `rust → build` · `ai-clis → node`.
- Manifest header syntax (exact): `## group: <name>`.
- All prompts read `/dev/tty`, never stdin (`bootstrap.sh` runs `exec </dev/null`).
- Verification block before every staging step:
  `bash tests/ubuntu-config.bash && bash -n setup.sh apply.sh doctor.sh bootstrap.sh setup/install-tools.sh setup/tools/installers.sh setup/lib/profile.sh setup/profile-select.sh setup/skills.sh tests/ubuntu-config.bash tests/profile-lib-test.bash home/dotf/.local/bin/dotf && zsh -n home/zsh/.zshrc home/zsh/.config/zsh/*.zsh`
  (drop paths that don't exist yet in early tasks).
- **Spec deviation (deliberate):** the spec asks to narrow the guard's dotf `stow -` pattern; instead `dotf profile` delegates wholly to `setup/profile-select.sh`, so dotf never contains the string and the guard stays at full strength. Do not narrow `tests/ubuntu-config.bash:163`.

---

### Task 1: `setup/lib/profile.sh` — registry, state, closure + unit tests

**Files:**
- Create: `setup/lib/profile.sh`
- Create: `tests/profile-lib-test.bash`
- Modify: `tests/ubuntu-config.bash` (invoke the unit tests at the end, before the failure summary)

**Interfaces (Produces — every later task consumes these exact names):**
- `DOTF_ALL_GROUPS` — array of the 11 non-core group names
- `dotf_state_file` → prints `${XDG_CONFIG_HOME:-$HOME/.config}/dotf/profile`
- `dotf_known_group <name>` → exit 0 iff name is in `DOTF_ALL_GROUPS`
- `dotf_group_deps <name>` → space-separated deps on stdout (empty for most)
- `dotf_group_stow_packages <name>` → space-separated stow packages (`core` → `zsh git tmux dotf`; `ergonomics` → `eza btop neofetch gh git-dev`; `nvim` → `nvim nvim-nightly`; `go-tools` → `lazygit`; others empty)
- `dotf_closure <csv>` → sorted, deduped csv incl. dependencies
- `dotf_parse_state <file>` → sets `DOTF_PROFILE` `DOTF_GROUPS` `DOTF_SKILLS` `DOTF_SKILLS_SET`; returns 0 ok / 2 missing / 1 invalid (reason on stderr)
- `dotf_load_state_ro` → parse + policy: missing → warn + `DOTF_PROFILE=developer`; invalid → message + `exit 1`; sets `DOTF_ACTIVE_GROUPS` (csv closure; empty for minimal, all for developer)
- `dotf_group_active <name>` → exit 0 iff active (`core` always)
- `dotf_write_state <profile> <groups-csv> [skills-csv]` → atomic tmp+mv; omitted skills arg preserves an existing `DOTF_SKILLS` line
- `dotf_filter_manifest <file>` → active-group package lines; structural errors → stderr + return 1
- `dotf_validate_manifest <file>` → structure check only (all lines under known headers), ignores active state
- `dotf_stow_packages` → active stow package names, one per line

- [ ] **Step 1: Write the failing unit tests**

Create `tests/profile-lib-test.bash`:

```bash
#!/usr/bin/env bash
# tests/profile-lib-test.bash - unit tests for setup/lib/profile.sh.
# Pure bash + mktemp fixtures; runs anywhere (incl. macOS bash 3.2), no apt.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/setup/lib/profile.sh"

failures=0
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export XDG_CONFIG_HOME="$tmpdir/config"   # isolate dotf_state_file

pass() { echo "  ok $1"; }
fail() { echo "  FAIL $1" >&2; failures=$((failures + 1)); }
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi; }
check_not() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then fail "$desc"; else pass "$desc"; fi; }
check_eq() { # desc actual expected
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi
}

# --- registry ---
check "known group: ergonomics" dotf_known_group ergonomics
check "known group: go-tools" dotf_known_group go-tools
check_not "unknown group rejected: banana" dotf_known_group banana
check_not "core is not a selectable group" dotf_known_group core
check_eq "state file honors XDG_CONFIG_HOME" "$(dotf_state_file)" "$tmpdir/config/dotf/profile"
check_eq "core stow packages" "$(dotf_group_stow_packages core)" "zsh git tmux dotf"
check_eq "ergonomics stow packages" "$(dotf_group_stow_packages ergonomics)" "eza btop neofetch gh git-dev"

# --- closure ---
check_eq "closure adds deps: nvim" "$(dotf_closure nvim)" "build,node,nvim"
check_eq "closure dedups: nvim,rust,node" "$(dotf_closure "nvim,rust,node")" "build,node,nvim,rust"
check_eq "closure of ai-clis" "$(dotf_closure ai-clis)" "ai-clis,node"
check_eq "closure of empty is empty" "$(dotf_closure "")" ""
check_eq "closure passthrough: media" "$(dotf_closure media)" "media"

# --- parse: valid / missing / invalid ---
sf="$tmpdir/state"
printf 'DOTF_PROFILE=custom\nDOTF_GROUPS=ergonomics,services\nDOTF_SKILLS=superpowers,graphify\n' > "$sf"
check "parse valid state" dotf_parse_state "$sf"
dotf_parse_state "$sf"
check_eq "parsed profile" "$DOTF_PROFILE" "custom"
check_eq "parsed groups" "$DOTF_GROUPS" "ergonomics,services"
check_eq "parsed skills" "$DOTF_SKILLS" "superpowers,graphify"
check_eq "skills marked set" "$DOTF_SKILLS_SET" "1"

dotf_parse_state "$tmpdir/nope"; check_eq "missing file returns 2" "$?" "2"

printf 'DOTF_PROFILE=custom\nDOTF_GROUPS=ergonomics\nrm -rf /\n' > "$sf"
dotf_parse_state "$sf"; check_eq "malformed line returns 1" "$?" "1"
printf 'DOTF_PROFILE=custom\nDOTF_GROUPS=banana\n' > "$sf"
dotf_parse_state "$sf"; check_eq "unknown group returns 1" "$?" "1"
printf 'DOTF_PROFILE=weird\nDOTF_GROUPS=\n' > "$sf"
dotf_parse_state "$sf"; check_eq "unknown profile returns 1" "$?" "1"
printf 'DOTF_PROFILE=minimal\nDOTF_PROFILE=developer\n' > "$sf"
dotf_parse_state "$sf"; check_eq "duplicate key returns 1" "$?" "1"
printf 'DOTF_PROFILE=minimal\nDOTF_GROUPS=\n' > "$sf"
dotf_parse_state "$sf"
check_eq "skills-absent means not asked" "$DOTF_SKILLS_SET" "0"

# --- write: atomic, preserve skills ---
dotf_write_state custom "ergonomics" "none"
check_eq "write round-trips" "$(cat "$(dotf_state_file)")" "DOTF_PROFILE=custom
DOTF_GROUPS=ergonomics
DOTF_SKILLS=none"
dotf_write_state minimal ""
check_eq "rewrite preserves skills line" "$(grep DOTF_SKILLS "$(dotf_state_file)")" "DOTF_SKILLS=none"
rm -f "$(dotf_state_file)"
dotf_write_state minimal ""
check_not "no skills line when never set" grep -q DOTF_SKILLS "$(dotf_state_file)"

# --- load_state_ro policy ---
rm -f "$(dotf_state_file)"
( dotf_load_state_ro 2>/dev/null; [[ "$DOTF_PROFILE" == developer ]] ) \
  && pass "missing state falls back to developer" || fail "missing state falls back to developer"
printf 'garbage\n' > "$(dotf_state_file)"
( dotf_load_state_ro 2>/dev/null ) && fail "invalid state exits 1" || pass "invalid state exits 1"
dotf_write_state custom "nvim"
( dotf_load_state_ro 2>/dev/null; [[ "$DOTF_ACTIVE_GROUPS" == "build,node,nvim" ]] ) \
  && pass "closure recomputed on load (migration case)" || fail "closure recomputed on load (migration case)"
dotf_write_state minimal ""
( dotf_load_state_ro 2>/dev/null; dotf_group_active core && ! dotf_group_active ergonomics ) \
  && pass "minimal: core active, ergonomics not" || fail "minimal: core active, ergonomics not"
dotf_write_state developer "$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")"
( dotf_load_state_ro 2>/dev/null; dotf_group_active media ) \
  && pass "developer: all groups active" || fail "developer: all groups active"

# --- manifest filter / validate ---
mf="$tmpdir/manifest.txt"
cat > "$mf" <<'EOF'
# comment
## group: core
sudo

## group: ergonomics
ripgrep
EOF
dotf_write_state minimal ""
dotf_load_state_ro 2>/dev/null
check_eq "filter: minimal sees only core" "$(dotf_filter_manifest "$mf")" "sudo"
dotf_write_state custom "ergonomics"
dotf_load_state_ro 2>/dev/null
check_eq "filter: ergonomics adds its section" "$(dotf_filter_manifest "$mf")" "sudo
ripgrep"
printf 'stray-package\n## group: core\nsudo\n' > "$mf"
check_not "filter: package before header fails" dotf_filter_manifest "$mf"
check_not "validate: package before header fails" dotf_validate_manifest "$mf"
printf '## group: banana\nx\n' > "$mf"
check_not "validate: unknown header fails" dotf_validate_manifest "$mf"
printf '## group: Banana\nx\n' > "$mf"
check_not "validate: malformed header fails (not comment-skipped)" dotf_validate_manifest "$mf"
printf '## group: core\nsudo\n## group: media\nimagemagick\n' > "$mf"
check "validate: well-formed passes" dotf_validate_manifest "$mf"

# --- stow packages ---
dotf_write_state minimal ""
dotf_load_state_ro 2>/dev/null
check_eq "stow: minimal" "$(dotf_stow_packages | paste -sd' ' -)" "zsh git tmux dotf"
dotf_write_state custom "ergonomics,go-tools"
dotf_load_state_ro 2>/dev/null
check_eq "stow: custom groups add packages" "$(dotf_stow_packages | paste -sd' ' -)" \
  "zsh git tmux dotf eza btop neofetch gh git-dev lazygit"

echo
if (( failures > 0 )); then
  echo "profile-lib tests: $failures failure(s)" >&2
  exit 1
fi
echo "profile-lib tests passed"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/profile-lib-test.bash`
Expected: FAIL — `setup/lib/profile.sh: No such file or directory`

- [ ] **Step 3: Implement `setup/lib/profile.sh`**

```bash
#!/usr/bin/env bash
# setup/lib/profile.sh - single source of truth for profiles, groups, and the
# state file. Sourced by setup.sh, apply.sh, doctor.sh, install-tools.sh,
# tools/installers.sh, profile-select.sh, skills.sh, and the tests.
# Spec: docs/superpowers/specs/2026-07-20-bootstrap-profiles-design.md
# Must run under bash 3.2 (macOS dev machines run the guard test).
# No side effects at source time; state file is parsed, never sourced.

DOTF_ALL_GROUPS=(ergonomics build services nvim node rust go-tools python ai-clis cloud media)

dotf_state_file() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/dotf/profile"
}

dotf_known_group() {
  local g
  for g in "${DOTF_ALL_GROUPS[@]}"; do
    [[ "$g" == "$1" ]] && return 0
  done
  return 1
}

dotf_group_deps() {
  case "$1" in
    nvim)    echo "build node" ;;
    rust)    echo "build" ;;
    ai-clis) echo "node" ;;
  esac
}

dotf_group_stow_packages() {
  case "$1" in
    core)       echo "zsh git tmux dotf" ;;
    ergonomics) echo "eza btop neofetch gh git-dev" ;;
    nvim)       echo "nvim nvim-nightly" ;;
    go-tools)   echo "lazygit" ;;
  esac
}

# csv in -> sorted deduped csv out, dependencies included. Recomputed on every
# load so registry changes migrate existing machines automatically.
dotf_closure() {
  local queue seen="" g d
  queue="${1//,/ }"
  while [[ -n "${queue// /}" ]]; do
    g="${queue%% *}"
    if [[ "$queue" == *" "* ]]; then queue="${queue#* }"; else queue=""; fi
    [[ -n "$g" ]] || continue
    case " $seen " in *" $g "*) continue ;; esac
    seen="$seen $g"
    for d in $(dotf_group_deps "$g"); do
      queue="$queue $d"
    done
  done
  [[ -n "${seen// /}" ]] || return 0
  # shellcheck disable=SC2086
  printf '%s\n' $seen | sort | paste -sd, -
}

# Sets DOTF_PROFILE, DOTF_GROUPS, DOTF_SKILLS, DOTF_SKILLS_SET.
# Returns 0 ok / 2 missing / 1 invalid (reason on stderr).
dotf_parse_state() {
  local file="$1" line key val seen_keys="," g
  DOTF_PROFILE="" DOTF_GROUPS="" DOTF_SKILLS="" DOTF_SKILLS_SET=0
  [[ -f "$file" ]] || return 2
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if [[ ! "$line" =~ ^(DOTF_PROFILE|DOTF_GROUPS|DOTF_SKILLS)=([a-z0-9@,._/-]*)$ ]]; then
      echo "!! invalid line in $file: $line" >&2
      return 1
    fi
    key="${BASH_REMATCH[1]}" val="${BASH_REMATCH[2]}"
    if [[ "$seen_keys" == *",$key,"* ]]; then
      echo "!! duplicate key $key in $file" >&2
      return 1
    fi
    seen_keys="$seen_keys$key,"
    case "$key" in
      DOTF_PROFILE) DOTF_PROFILE="$val" ;;
      DOTF_GROUPS)  DOTF_GROUPS="$val" ;;
      DOTF_SKILLS)  DOTF_SKILLS="$val"; DOTF_SKILLS_SET=1 ;;
    esac
  done < "$file"
  case "$DOTF_PROFILE" in
    minimal|developer|custom) ;;
    *) echo "!! invalid DOTF_PROFILE '$DOTF_PROFILE' in $file" >&2; return 1 ;;
  esac
  if [[ -n "$DOTF_GROUPS" ]]; then
    for g in ${DOTF_GROUPS//,/ }; do
      if ! dotf_known_group "$g"; then
        echo "!! unknown group '$g' in $file" >&2
        return 1
      fi
    done
  fi
  return 0
}

# Read-only load policy: missing -> developer fallback with a warning;
# invalid -> hard error pointing at 'dotf profile'. Sets DOTF_ACTIVE_GROUPS.
dotf_load_state_ro() {
  local file rc=0
  file="$(dotf_state_file)"
  dotf_parse_state "$file" || rc=$?
  if (( rc == 2 )); then
    echo "!! no profile state at $file — assuming 'developer' (run 'dotf profile' to choose)." >&2
    DOTF_PROFILE=developer
  elif (( rc == 1 )); then
    echo "!! invalid profile state at $file — run 'dotf profile' to repair it." >&2
    exit 1
  fi
  case "$DOTF_PROFILE" in
    minimal)   DOTF_ACTIVE_GROUPS="" ;;
    developer) DOTF_ACTIVE_GROUPS="$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" ;;
    custom)    DOTF_ACTIVE_GROUPS="$(dotf_closure "$DOTF_GROUPS")" ;;
  esac
}

dotf_group_active() {
  [[ "$1" == "core" ]] && return 0
  [[ ",${DOTF_ACTIVE_GROUPS:-}," == *",$1,"* ]]
}

# Atomic write. Third arg omitted -> preserve an existing DOTF_SKILLS line.
dotf_write_state() {
  local profile="$1" groups="$2" skills="${3-__preserve__}" file dir tmp rc=0
  file="$(dotf_state_file)"
  dir="$(dirname "$file")"
  mkdir -p "$dir"
  if [[ "$skills" == "__preserve__" ]]; then
    skills=""
    dotf_parse_state "$file" || rc=$?
    if (( rc == 0 )) && (( DOTF_SKILLS_SET )); then
      skills="$DOTF_SKILLS"
    fi
  fi
  tmp="$(mktemp "$dir/.profile-write.XXXXXX")"
  {
    echo "DOTF_PROFILE=$profile"
    echo "DOTF_GROUPS=$groups"
    [[ -n "$skills" ]] && echo "DOTF_SKILLS=$skills"
  } > "$tmp"
  mv "$tmp" "$file"
}

# Shared manifest walker. $2 = 1 -> also emit active-group package lines.
_dotf_walk_manifest() {
  local file="$1" emit="$2" line group=""
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^##\ group:\ ([a-z-]+)$ ]]; then
      group="${BASH_REMATCH[1]}"
      if [[ "$group" != "core" ]] && ! dotf_known_group "$group"; then
        echo "!! $file: unknown group header '$group'" >&2
        return 1
      fi
      continue
    fi
    # A header-looking line that failed the strict regex must be an error, not
    # a silently-skipped comment (its packages would inherit the wrong group).
    if [[ "$line" == '## group:'* ]]; then
      echo "!! $file: malformed group header: $line" >&2
      return 1
    fi
    case "$line" in ''|\#*|[[:space:]]*\#*) continue ;; esac
    [[ -z "${line// /}" ]] && continue
    if [[ -z "$group" ]]; then
      echo "!! $file: package line before any '## group:' header: $line" >&2
      return 1
    fi
    if (( emit )) && dotf_group_active "$group"; then
      printf '%s\n' "$line"
    fi
  done < "$file"
}

dotf_filter_manifest()   { _dotf_walk_manifest "$1" 1; }
dotf_validate_manifest() { _dotf_walk_manifest "$1" 0; }

# Stow packages for the active groups, one per line, core first.
dotf_stow_packages() {
  local g p
  for g in core "${DOTF_ALL_GROUPS[@]}"; do
    dotf_group_active "$g" || continue
    for p in $(dotf_group_stow_packages "$g"); do
      printf '%s\n' "$p"
    done
  done
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/profile-lib-test.bash`
Expected: every line `ok …`, final line `profile-lib tests passed`, exit 0.

- [ ] **Step 5: Wire into the guard test**

In `tests/ubuntu-config.bash`, immediately before the final `if (( failures > 0 )); then` block, add:

```bash
# profile library unit tests (pure bash; must pass everywhere the guard runs)
if ! bash "$ROOT/tests/profile-lib-test.bash"; then
  fail "tests/profile-lib-test.bash failed"
fi
```

- [ ] **Step 6: Verify**

Run: `bash tests/ubuntu-config.bash && bash -n setup/lib/profile.sh tests/profile-lib-test.bash`
Expected: `profile-lib tests passed` then `Ubuntu config checks passed`; both `bash -n` silent.

- [ ] **Step 7: Stage and hand off**

```bash
git add setup/lib/profile.sh tests/profile-lib-test.bash tests/ubuntu-config.bash
```
Tell the user Task 1 is ready for `/pc:commit`.

---

### Task 2: Group headers in all five manifests + guard structure rules

**Files:**
- Modify: `setup/apt-packages.txt`, `setup/tools/npm.txt`, `setup/tools/bun.txt`, `setup/tools/cargo.txt`, `setup/tools/go.txt`
- Modify: `tests/ubuntu-config.bash`

**Interfaces:**
- Consumes: `dotf_validate_manifest` (Task 1)
- Produces: manifests whose every package line sits under a `## group:` header — the exact group assignments below are load-bearing for Tasks 3–5.

- [ ] **Step 1: Add guard rules (failing first)**

In `tests/ubuntu-config.bash`, after the existing manifest checks (below the `assert_contains '^rtk$' "setup/tools/cargo.txt"` line), add:

```bash
# Every manifest must be group-sectioned; headers must name known groups.
. "$ROOT/setup/lib/profile.sh"
for manifest in setup/apt-packages.txt setup/tools/npm.txt setup/tools/bun.txt \
                setup/tools/cargo.txt setup/tools/go.txt; do
  if ! dotf_validate_manifest "$ROOT/$manifest" >/dev/null; then
    fail "$manifest is not a valid group-sectioned manifest"
  fi
done
```

Run: `bash tests/ubuntu-config.bash`
Expected: FAIL ×5 — `package line before any '## group:' header`.

- [ ] **Step 2: Rewrite `setup/apt-packages.txt`**

```
# Ubuntu apt packages for headless CLI and service development.
# One package per line under a '## group: <name>' header. Blank lines and
# plain # comments are ignored; the group headers drive profile filtering.

## group: core
sudo
ca-certificates
software-properties-common
curl
wget
git
zsh
stow
tmux
less
jq
tree
unzip
zip
rsync
htop
ncurses-term

## group: ergonomics
ripgrep
fd-find
fzf
bat
eza
git-delta
zoxide
btop
ncdu
direnv
just
thefuck
telnet
shellcheck
gh

## group: build
build-essential
pkg-config
cmake
ninja-build
gettext
libssl-dev
libreadline-dev
zlib1g-dev
libsqlite3-dev
libbz2-dev
libffi-dev
liblzma-dev

## group: go-tools
golang-go

## group: python
python3-pip
python3-venv
pipx

## group: nvim
luarocks

## group: services
docker.io
docker-compose-v2
postgresql-client
redis-tools

## group: media
imagemagick
poppler-utils
```

- [ ] **Step 3: Rewrite the four tool manifests**

`setup/tools/npm.txt`:
```
# npm global packages — one per line under a group header.
# Installed with: npm install -g <pkg>
# (claude code and opencode are installed via installers.sh, not here.)

## group: node
portless
typescript

## group: nvim
tree-sitter-cli

## group: ai-clis
@openai/codex
```

`setup/tools/bun.txt`:
```
# bun global packages — one per line under a group header.
# Installed with: bun add -g <pkg>

## group: node
# (none yet — add packages here)
```

`setup/tools/cargo.txt`:
```
# cargo crates — one per line under a group header.
# Installed with: cargo install --locked <crate>

## group: rust
yazi-build
rtk
```

`setup/tools/go.txt`:
```
# go packages — one "import/path@version" per line under a group header.
# Installed with: go install <import/path@version>   (the @version is REQUIRED)

## group: go-tools
github.com/charmbracelet/gum@latest
github.com/jesseduffield/lazygit@latest
```

- [ ] **Step 4: Verify**

Run: `bash tests/ubuntu-config.bash`
Expected: PASS — the `@openai/codex` line's `@` is covered because `_dotf_walk_manifest` only comment-skips lines *starting* with `#`; the existing `assert_contains '^tree-sitter-cli$' "setup/tools/npm.txt"` and cargo/rtk rules still pass.

- [ ] **Step 5: Stage and hand off**

```bash
git add setup/apt-packages.txt setup/tools/npm.txt setup/tools/bun.txt setup/tools/cargo.txt setup/tools/go.txt tests/ubuntu-config.bash
```

---

### Task 3: Minimal-usability config — guarded zsh aliases + git-dev split

**Files:**
- Modify: `home/zsh/.config/zsh/30-aliases.zsh`
- Modify: `home/zsh/.config/zsh/00-env.zsh`
- Modify: `home/git/.gitconfig`
- Create: `home/git-dev/.config/git/dev.gitconfig`
- Modify: `tests/ubuntu-config.bash`

**Interfaces:**
- Produces: stow package `git-dev` (Task 1's registry already maps it to ergonomics).

- [ ] **Step 1: Add guard rules (failing first)**

In `tests/ubuntu-config.bash` after the existing zsh checks:

```bash
# Minimal profile must keep a working shell: no unguarded aliases to
# optional-group binaries, and git's delta/nvim config must live in the
# ergonomics-mapped git-dev include, not core.
assert_no_pattern "^alias (ls|ll|tree)='eza" "home/zsh/.config/zsh/30-aliases.zsh"
assert_no_pattern "^alias cat='bat'" "home/zsh/.config/zsh/30-aliases.zsh"
assert_no_pattern "^alias vim='nvim'" "home/zsh/.config/zsh/30-aliases.zsh"
assert_no_pattern 'delta|nvim' "home/git/.gitconfig"
assert_contains 'path = ~/\.config/git/dev\.gitconfig' "home/git/.gitconfig"
assert_contains 'delta --dark' "home/git-dev/.config/git/dev.gitconfig"
```

Run: `bash tests/ubuntu-config.bash` — Expected: FAIL on each new rule.

- [ ] **Step 2: Guard the zsh aliases**

Replace the top of `home/zsh/.config/zsh/30-aliases.zsh` (editor + listing sections and the `lg`/AI-tool lines) with:

```zsh
# Editor aliases (guarded: minimal profile ships no nvim).
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
  alias vimdiff='nvim -d'
fi

# Navigation and listing replacements (guarded: ergonomics group optional).
alias lsu='du -sh ./* | sort -hr | head -n 10'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza'
  alias ll='eza -alh'
  alias tree='eza --tree'
fi
command -v bat >/dev/null 2>&1 && alias cat='bat'
```

and guard the tool aliases further down:

```zsh
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'

# AI tools.
command -v claude >/dev/null 2>&1 && alias cc='claude'
command -v opencode >/dev/null 2>&1 && alias oc='opencode'
```

(Keep `lsu`, `cdx`, `tmx`, `tmk`, `snv`, pnpm, docker, and `nb` lines unchanged.)

In `home/zsh/.config/zsh/00-env.zsh` replace `export EDITOR=nvim` with:

```zsh
if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim
else
  export EDITOR=vi
fi
```

- [ ] **Step 3: Split the git config**

`home/git/.gitconfig` becomes (delta/nvim settings removed, include added; identity/lfs/pull/init/merge-conflictstyle/diff stay):

```gitconfig
# Set your identity in ~/.gitconfig.local (untracked), e.g.:
#   [user]
#       name = Your Name
#       email = you@example.com
[include]
	path = ~/.gitconfig.local
# Developer-experience settings (pager, editor, merge/diff tools) are stowed
# by the ergonomics group; git ignores a missing include. Keep the words
# 'delta'/'nvim' out of this file — the guard forbids them here.
[include]
	path = ~/.config/git/dev.gitconfig
[init]
	defaultBranch = main
[pull]
	rebase = false
[filter "lfs"]
	required = true
	clean = git-lfs clean -- %f
	smudge = git-lfs smudge -- %f
	process = git-lfs filter-process
[merge]
	conflictstyle = diff3
[diff]
	colorMoved = default
```

Create `home/git-dev/.config/git/dev.gitconfig`:

```gitconfig
# Developer-experience git settings. Stowed by the ergonomics group; the base
# ~/.gitconfig includes this path and git ignores it when absent (minimal).
[core]
	editor = nvim
	pager = delta --dark
[interactive]
	diffFilter = delta --color-only
[delta]
	navigate = true
	line-numbers = true
	side-by-side = false
	syntax-theme = Dracula
	true-color = always
[merge]
	tool = nvimdiff
[mergetool "nvimdiff"]
	layout = "LOCAL,MERGED,REMOTE"
	path = nvim
[mergetool]
	prompt = false
```

- [ ] **Step 4: Verify**

Run: `bash tests/ubuntu-config.bash && zsh -n home/zsh/.zshrc home/zsh/.config/zsh/*.zsh`
Expected: PASS. Also spot-check: `git -c include.path=/dev/null config --file home/git/.gitconfig core.pager` prints nothing (delta really moved out).

- [ ] **Step 5: Stage and hand off**

```bash
git add home/zsh/.config/zsh/30-aliases.zsh home/zsh/.config/zsh/00-env.zsh home/git/.gitconfig home/git-dev tests/ubuntu-config.bash
```

---

### Task 4: `apply.sh` — group-aware apt, stow, services, skills hook

**Files:**
- Modify: `apply.sh`

**Interfaces:**
- Consumes: `dotf_load_state_ro`, `dotf_filter_manifest`, `dotf_stow_packages`, `dotf_group_active` (Task 1)
- Produces: `apply.sh` runs `setup/skills.sh` (created in Task 8) when `ai-clis` is active and the script exists — guarded with `[[ -x ]]` so this task lands before Task 8.

- [ ] **Step 1: Source the library and load state**

In `apply.sh`, after `DOTFILES="$(…)"` (line 9), add:

```bash
# shellcheck source=setup/lib/profile.sh
. "$DOTFILES/setup/lib/profile.sh"
dotf_load_state_ro
```

- [ ] **Step 2: Filter apt by group**

In `install_apt_packages`, change the loop feed (line 48) from
`done < <(read_manifest "$APT_PACKAGES")` to:

```bash
  done < <(dotf_filter_manifest "$APT_PACKAGES")
```

and change the section header to print the profile:

```bash
  section "Installing apt CLI and service packages (profile: $DOTF_PROFILE)"
```

(`read_manifest` stays — `doctor.sh` transition happens in Task 6; remove it from `apply.sh` only, where it is now unused.)

- [ ] **Step 3: Stow only active packages**

In `stow_dotfiles`, replace the `find`-based package discovery (lines 141–150) with:

```bash
  local packages=()
  local package
  while IFS= read -r package; do
    [[ -d "$DOTFILES/home/$package" ]] || {
      echo "!! stow package '$package' missing under $DOTFILES/home" >&2
      exit 1
    }
    packages+=("$package")
  done < <(dotf_stow_packages)

  if (( ${#packages[@]} == 0 )); then
    echo "!! No stow packages resolved for profile '$DOTF_PROFILE'"
    exit 1
  fi
```

- [ ] **Step 4: Gate docker service**

At the top of `configure_services` add:

```bash
  if ! dotf_group_active services; then
    echo "  -> services group inactive; skipping"
    return 0
  fi
```

- [ ] **Step 5: Skills hook at the end of `main`**

In `main`, after `reload_tmux_config` and before the clone-failure summary:

```bash
  if dotf_group_active ai-clis && [[ -x "$DOTFILES/setup/skills.sh" ]]; then
    section "AI skill frameworks"
    "$DOTFILES/setup/skills.sh" || true
  fi
```

- [ ] **Step 6: Verify**

Run: `bash tests/ubuntu-config.bash && bash -n apply.sh`
Expected: PASS (the guard's stow-ordering awk still matches — `stow_dotfiles`, `"$DOTFILES/setup/install-tools.sh"` etc. keep their exact call lines).

- [ ] **Step 7: Stage and hand off**

```bash
git add apply.sh
```

---

### Task 5: `install-tools.sh` + `installers.sh` — group-gated bootstraps

**Files:**
- Modify: `setup/install-tools.sh`
- Modify: `setup/tools/installers.sh`

**Interfaces:**
- Consumes: `dotf_load_state_ro`, `dotf_group_active`, `dotf_filter_manifest` (Task 1)

- [ ] **Step 1: Gate `install-tools.sh`**

After `TOOLS_DIR=…` add:

```bash
# shellcheck source=lib/profile.sh
. "$SCRIPT_DIR/lib/profile.sh"
dotf_load_state_ro
```

In `install_from_manifest`, replace the `raw="$(grep -vE …)"` line with:

```bash
  local raw
  raw="$(dotf_filter_manifest "$file")" || {
    FAILURES+=("$name manifest (structure error)")
    return 0
  }
```

Rewrite the bootstrap block of `main` as:

```bash
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
```

(The manifest install calls stay unconditional — filtering happens inside
`install_from_manifest`, and an empty filtered manifest is a no-op.)

- [ ] **Step 2: Gate `installers.sh`**

After the `export PATH=…` line add:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/profile.sh
. "$SCRIPT_DIR/../lib/profile.sh"
dotf_load_state_ro
```

Wrap the trailing invocation blocks:

```bash
if dotf_group_active cloud && ! command -v aws >/dev/null 2>&1; then
  echo "  -> installing aws cli v2"
  install_aws_cli
fi

if dotf_group_active nvim && ! command -v lua-language-server >/dev/null 2>&1; then
  echo "  -> installing lua-language-server"
  install_lua_language_server
fi

if [[ ! -d "$HOME/.zsh/zsh-completions/src" ]]; then
  echo "  -> installing zsh-completions"
  install_zsh_completions
fi

if dotf_group_active ai-clis && ! command -v claude >/dev/null 2>&1; then
  echo "  -> installing claude code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

if dotf_group_active ai-clis && ! command -v opencode >/dev/null 2>&1; then
  echo "  -> installing opencode"
  curl -fsSL https://opencode.ai/install | bash
fi
```

(zsh-completions stays unconditional — it is core.)

- [ ] **Step 3: Verify**

Run: `bash tests/ubuntu-config.bash && bash -n setup/install-tools.sh setup/tools/installers.sh`
Expected: PASS — the guard's `install_from_manifest "cargo".*cargo install --locked`, awscli, lua-ls, and zsh-completions assertions all still match.

- [ ] **Step 4: Stage and hand off**

```bash
git add setup/install-tools.sh setup/tools/installers.sh
```

---

### Task 6: `doctor.sh` — profile-aware, still read-only

**Files:**
- Modify: `doctor.sh`

**Interfaces:**
- Consumes: `dotf_load_state_ro`, `dotf_filter_manifest`, `dotf_stow_packages`, `dotf_group_active` (Task 1)

- [ ] **Step 1: Load state and report it**

After `APT_PACKAGES=…` add:

```bash
# shellcheck source=setup/lib/profile.sh
. "$DOTFILES/setup/lib/profile.sh"
```

At the top of `main`:

```bash
  section "Profile"
  dotf_load_state_ro
  if [[ -f "$(dotf_state_file)" ]]; then
    ok "profile: $DOTF_PROFILE (groups: ${DOTF_ACTIVE_GROUPS:-core only})"
  else
    warn "no profile state — assuming developer; run 'dotf profile' to choose"
  fi
```

(`dotf_load_state_ro` hard-exits on an invalid file with the `dotf profile`
hint — acceptable for doctor: an unreadable state is itself the drift report.)

- [ ] **Step 2: Filter the checks**

- Required commands: replace the fixed list with:

```bash
  local cmds="sudo apt-get git stow zsh tmux curl"
  dotf_group_active nvim && cmds="$cmds nvim"
  for cmd in $cmds; do
```

- Apt loop feed: `done < <(read_manifest "$APT_PACKAGES")` → `done < <(dotf_filter_manifest "$APT_PACKAGES")`. Delete the now-unused `read_manifest`.
- Stow dry-run package list: replace the `find` loop with:

```bash
    local packages=()
    local package
    while IFS= read -r package; do
      packages+=("$package")
    done < <(dotf_stow_packages)
```

- [ ] **Step 3: Verify**

Run: `bash tests/ubuntu-config.bash && bash -n doctor.sh`
Expected: PASS. Manual spot-check on this (macOS) machine is expected to fail platform checks — do not run `./doctor.sh` here to judge success; syntax + guard only.

- [ ] **Step 4: Stage and hand off**

```bash
git add doctor.sh
```

---

### Task 7: `setup/profile-select.sh` + `setup.sh` integration

**Files:**
- Create: `setup/profile-select.sh` (executable)
- Modify: `setup.sh`

**Interfaces:**
- Consumes: `dotf_parse_state`, `dotf_write_state`, `dotf_closure`, `dotf_state_file`, `DOTF_ALL_GROUPS`, `dotf_group_stow_packages` (Task 1)
- Produces: `setup/profile-select.sh [--if-missing]` — exit 0 after ensuring a valid state file exists; `dotf profile` (Task 9) calls it with no flag to force reselection.

- [ ] **Step 1: Implement `setup/profile-select.sh`**

```bash
#!/usr/bin/env bash
# profile-select.sh - interactive profile/group selection; writes the state
# file. The ONLY writers of the state file are this script and skills.sh.
# Usage: profile-select.sh [--if-missing]
#   --if-missing  keep an existing valid state untouched (setup.sh mode)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/profile.sh
. "$SCRIPT_DIR/lib/profile.sh"

IF_MISSING=0
[[ "${1:-}" == "--if-missing" ]] && IF_MISSING=1

old_stow_packages() {
  # Stow set of the pre-existing state (if valid) for the orphan report.
  local rc=0
  dotf_parse_state "$(dotf_state_file)" || rc=$?
  (( rc == 0 )) || return 0
  case "$DOTF_PROFILE" in
    minimal)   DOTF_ACTIVE_GROUPS="" ;;
    developer) DOTF_ACTIVE_GROUPS="$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" ;;
    custom)    DOTF_ACTIVE_GROUPS="$(dotf_closure "$DOTF_GROUPS")" ;;
  esac
  dotf_stow_packages
}

prompt_custom_groups() {
  local i choice picks csv="" idx name
  {
    echo "Groups (core is always included):"
    i=1
    for name in "${DOTF_ALL_GROUPS[@]}"; do
      echo "  $i) $name"
      i=$((i + 1))
    done
  } > /dev/tty
  while :; do
    printf 'Pick groups (comma-separated numbers, empty for none): ' > /dev/tty
    IFS= read -r picks < /dev/tty || picks=""
    csv=""
    local ok=1
    for choice in ${picks//,/ }; do
      if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#DOTF_ALL_GROUPS[@]} )); then
        echo "  !! invalid selection: $choice" > /dev/tty
        ok=0
        break
      fi
      idx=$((choice - 1))
      name="${DOTF_ALL_GROUPS[$idx]}"
      [[ ",$csv," == *",$name,"* ]] || csv="${csv:+$csv,}$name"
    done
    (( ok )) && break
  done
  printf '%s\n' "$csv"
}

main() {
  local rc=0
  dotf_parse_state "$(dotf_state_file)" || rc=$?
  if (( IF_MISSING )) && (( rc == 0 )); then
    echo "==> Profile already selected: $DOTF_PROFILE (change with 'dotf profile')"
    return 0
  fi
  (( rc == 1 )) && echo "!! existing state at $(dotf_state_file) is invalid — reselecting."

  local old_pkgs
  old_pkgs="$(old_stow_packages || true)"

  if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
    echo "==> Non-interactive: defaulting to the 'developer' profile."
    dotf_write_state developer "$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")"
    return 0
  fi

  local choice profile groups=""
  while :; do
    {
      echo "Select a profile:"
      echo "  1) minimal    — server essentials only"
      echo "  2) developer  — everything (editor stack, runtimes, AI CLIs)"
      echo "  3) custom     — essentials + groups you pick"
      printf 'Choice [1-3]: '
    } > /dev/tty
    IFS= read -r choice < /dev/tty || choice=""
    case "$choice" in
      1) profile=minimal;   groups="" ;;
      2) profile=developer; groups="$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" ;;
      3) profile=custom;    groups="$(prompt_custom_groups)" ;;
      *) echo "  !! pick 1, 2, or 3" > /dev/tty; continue ;;
    esac
    break
  done

  if [[ "$profile" == "custom" && -n "$groups" ]]; then
    # Compare against the SORTED picks so pure reordering never reads as
    # "dependencies added".
    local closed picked_sorted
    closed="$(dotf_closure "$groups")"
    # shellcheck disable=SC2086
    picked_sorted="$(printf '%s\n' ${groups//,/ } | sort | paste -sd, -)"
    if [[ "$closed" != "$picked_sorted" ]]; then
      echo "==> Added dependency groups: closure is '$closed' (you picked '$groups')."
    fi
    groups="$closed"
  fi

  dotf_write_state "$profile" "$groups"
  echo "==> Profile '$profile' saved to $(dotf_state_file)"

  # Orphan report: stow packages the new selection no longer covers.
  if [[ -n "$old_pkgs" ]]; then
    case "$profile" in
      minimal)   DOTF_ACTIVE_GROUPS="" ;;
      developer) DOTF_ACTIVE_GROUPS="$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" ;;
      custom)    DOTF_ACTIVE_GROUPS="$(dotf_closure "$groups")" ;;
    esac
    local new_pkgs pkg orphan=0
    new_pkgs="$(dotf_stow_packages)"
    for pkg in $old_pkgs; do
      if ! printf '%s\n' "$new_pkgs" | grep -qx "$pkg"; then
        (( orphan )) || echo "==> No-longer-active stow packages (not removed automatically):"
        orphan=1
        echo "    $pkg — remove with: cd \"\$HOME/.dotfiles\" && stow -D $pkg"
      fi
    done
    (( orphan )) && echo "    Installed tools from removed groups also remain; uninstall manually if unwanted."
  fi
  return 0
}

main "$@"
```

Make it executable: `chmod +x setup/profile-select.sh`.

- [ ] **Step 2: Call it from `setup.sh`**

In `setup.sh` `main`, between the prerequisites install and the apply call:

```bash
  echo "==> Selecting profile"
  "$DOTFILES/setup/profile-select.sh" --if-missing
```

- [ ] **Step 3: Verify (scripted, non-interactive path)**

```bash
bash -n setup/profile-select.sh setup.sh
d="$(mktemp -d)"; XDG_CONFIG_HOME="$d" setup/profile-select.sh   # answer: 1
cat "$d/dotf/profile"
```
Expected: prompt appears (note: `</dev/null` does NOT exercise the non-tty
path — `/dev/tty` is still reachable from a terminal; the non-interactive
branch is exercised in the VM matrix). After answering `1`, the file prints
`DOTF_PROFILE=minimal` and `DOTF_GROUPS=`. Then `bash tests/ubuntu-config.bash` → PASS.

- [ ] **Step 4: Stage and hand off**

```bash
git add setup/profile-select.sh setup.sh
```

---

### Task 8: `setup/skills.sh` — AI skill frameworks

**Files:**
- Create: `setup/skills.sh` (executable)

**Interfaces:**
- Consumes: `dotf_parse_state`, `dotf_write_state`, `dotf_state_file` (Task 1). Invoked by `apply.sh` (Task 4 hook) and `dotf skills` (Task 9, passes `--reselect`).
- Produces: `setup/skills.sh [--reselect]`.

Install commands below were verified against each project's current README on
2026-07-20 (graphify docs live on its `v8` branch; its PyPI name is `graphifyy`
with CLI `graphify`; SuperClaude's Claude-plugin route is not shipped yet —
pipx is the documented path).

- [ ] **Step 1: Implement `setup/skills.sh`**

```bash
#!/usr/bin/env bash
# skills.sh - optional AI skill frameworks. Idempotent by re-running each
# framework's official install/update command — never by presence-skip.
# DOTF_SKILLS: absent = never asked · 'none' = declined · csv = install these.
# Usage: skills.sh [--reselect]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/profile.sh
. "$SCRIPT_DIR/lib/profile.sh"
export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$HOME/.fnm:$PATH"
command -v fnm >/dev/null 2>&1 && eval "$(fnm env --shell bash)" 2>/dev/null

RESELECT=0
[[ "${1:-}" == "--reselect" ]] && RESELECT=1
FAILURES=()

# slug|label|needs-claude(0/1)
CATALOG="superclaude|SuperClaude Framework|0
superpowers|Superpowers (obra)|1
mattpocock-skills|mattpocock/skills|1
graphify|Graphify|0
react-devtools|react-devtools (Callstack; browser mode needs headed Chromium)|1
callstack-agent-skills|Callstack agent-skills (React Native)|1"

catalog_visible() {
  local line slug label needs
  while IFS='|' read -r slug label needs; do
    if [[ "$needs" == "1" ]] && ! command -v claude >/dev/null 2>&1; then
      continue
    fi
    printf '%s|%s\n' "$slug" "$label"
  done <<< "$CATALOG"
}

prompt_selection() {
  local i=1 slug label lines choice picks csv=""
  lines="$(catalog_visible)"
  {
    echo "AI skill frameworks (comma-separated numbers, empty for none):"
    while IFS='|' read -r slug label; do
      echo "  $i) $label"
      i=$((i + 1))
    done <<< "$lines"
    printf 'Pick: '
  } > /dev/tty
  IFS= read -r picks < /dev/tty || picks=""
  local total=$((i - 1))
  for choice in ${picks//,/ }; do
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > total )); then
      echo "  !! ignoring invalid selection: $choice" > /dev/tty
      continue
    fi
    slug="$(printf '%s\n' "$lines" | sed -n "${choice}p" | cut -d'|' -f1)"
    [[ ",$csv," == *",$slug,"* ]] || csv="${csv:+$csv,}$slug"
  done
  printf '%s\n' "${csv:-none}"
}

run_step() {
  local label="$1"
  shift
  echo "  -> $label"
  if "$@"; then
    return 0
  fi
  FAILURES+=("$label")
  return 0
}

install_one() {
  case "$1" in
    superclaude)
      if ! command -v pipx >/dev/null 2>&1; then
        FAILURES+=("superclaude (needs pipx — enable the python group)")
        return 0
      fi
      pipx install superclaude >/dev/null 2>&1 || run_step "superclaude: pipx upgrade" pipx upgrade superclaude
      run_step "superclaude install" superclaude install
      ;;
    superpowers)
      run_step "superpowers plugin" claude plugin install superpowers@claude-plugins-official
      ;;
    mattpocock-skills)
      run_step "mattpocock marketplace" claude plugin marketplace add mattpocock/skills
      run_step "mattpocock plugin" claude plugin install mattpocock-skills@mattpocock
      ;;
    graphify)
      if command -v uv >/dev/null 2>&1; then
        run_step "graphify: uv tool install" uv tool install graphifyy
      elif command -v pipx >/dev/null 2>&1; then
        run_step "graphify: pipx install" pipx install graphifyy
      else
        FAILURES+=("graphify (needs uv or pipx — enable the python group)")
        return 0
      fi
      command -v graphify >/dev/null 2>&1 && run_step "graphify install" graphify install
      ;;
    react-devtools)
      if ! command -v npx >/dev/null 2>&1; then
        FAILURES+=("react-devtools (needs node/npx)")
        return 0
      fi
      # No subshell around run_step — FAILURES+=() inside one would be lost.
      run_step "react-devtools skill" bash -c \
        'cd "$HOME" && npx -y skills add callstackincubator/agent-react-devtools --skill react-devtools --agent claude-code'
      ;;
    callstack-agent-skills)
      run_step "callstack marketplace" claude plugin marketplace add callstackincubator/agent-skills
      run_step "callstack react-native-best-practices" \
        claude plugin install react-native-best-practices@callstack-agent-skills
      ;;
    *)
      FAILURES+=("unknown skill slug '$1' — re-run 'dotf skills'")
      ;;
  esac
}

main() {
  local rc=0
  dotf_parse_state "$(dotf_state_file)" || rc=$?
  if (( rc == 1 )); then
    echo "!! invalid profile state — run 'dotf profile' first." >&2
    exit 1
  fi

  if (( RESELECT )) || (( ! DOTF_SKILLS_SET )); then
    if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
      echo "==> Non-interactive and skills never selected; skipping (a later interactive run will ask)."
      return 0
    fi
    DOTF_SKILLS="$(prompt_selection)"
    # rc==2: no state file (skills.sh run standalone) — persist under developer.
    if (( rc == 2 )); then
      dotf_write_state developer "$(IFS=,; echo "${DOTF_ALL_GROUPS[*]}")" "$DOTF_SKILLS"
    else
      dotf_write_state "$DOTF_PROFILE" "$DOTF_GROUPS" "$DOTF_SKILLS"
    fi
    echo "==> Skills selection saved: $DOTF_SKILLS"
  fi

  if [[ "$DOTF_SKILLS" == "none" || -z "$DOTF_SKILLS" ]]; then
    echo "==> No AI skill frameworks selected."
    return 0
  fi

  local slug
  for slug in ${DOTF_SKILLS//,/ }; do
    echo "==> Installing skill framework: $slug"
    install_one "$slug"
  done

  echo
  if (( ${#FAILURES[@]} )); then
    echo "==> Skills completed with ${#FAILURES[@]} issue(s):"
    printf '    - %s\n' "${FAILURES[@]}"
    echo "    Re-run 'dotf skills' to retry."
    return 0
  fi
  echo "==> All selected skill frameworks installed."
}

main "$@"
```

Make it executable: `chmod +x setup/skills.sh`.

- [ ] **Step 2: Verify**

```bash
bash -n setup/skills.sh
XDG_CONFIG_HOME="$(mktemp -d)" setup/skills.sh </dev/null
```
Expected: non-interactive run prints `Non-interactive and skills never selected; skipping …` and exits 0. Then `bash tests/ubuntu-config.bash` → PASS.

- [ ] **Step 3: Stage and hand off**

```bash
git add setup/skills.sh
```

---

### Task 9: `dotf profile` + `dotf skills` subcommands

**Files:**
- Modify: `home/dotf/.local/bin/dotf`

**Interfaces:**
- Consumes: `setup/profile-select.sh` (Task 7), `setup/skills.sh --reselect` (Task 8), `apply.sh`.

- [ ] **Step 1: Extend usage text and dispatch**

In the `usage()` heredoc add after the `update` line:

```
  profile           Re-select profile/groups, then converge (apply.sh)
  skills            Re-select and install AI skill frameworks
```

In the dispatch `case` add before `*)`:

```bash
    profile) "$root/setup/profile-select.sh" && exec "$root/apply.sh" ;;
    skills)  exec "$root/setup/skills.sh" --reselect ;;
```

- [ ] **Step 2: Add new scripts to `cmd_test`'s `bash -n` list**

```bash
  bash -n \
    "$root/setup.sh" \
    "$root/apply.sh" \
    "$root/doctor.sh" \
    "$root/bootstrap.sh" \
    "$root/setup/install-tools.sh" \
    "$root/setup/tools/installers.sh" \
    "$root/setup/lib/profile.sh" \
    "$root/setup/profile-select.sh" \
    "$root/setup/skills.sh" \
    "$root/tests/ubuntu-config.bash" \
    "$root/tests/profile-lib-test.bash" \
    "$root/home/dotf/.local/bin/dotf"
```

- [ ] **Step 3: Verify**

Run: `bash tests/ubuntu-config.bash && bash -n home/dotf/.local/bin/dotf`
Expected: PASS — dotf still contains no `apt-get`/`stow -`/`sudo ` (delegation keeps the strict guard intact; do NOT relax `tests/ubuntu-config.bash:163`).

- [ ] **Step 4: Stage and hand off**

```bash
git add home/dotf/.local/bin/dotf
```

---

### Task 10: `bootstrap.sh` new-user step

**Files:**
- Modify: `bootstrap.sh`
- Modify: `tests/ubuntu-config.bash`

**Interfaces:**
- Produces: functions `dotf_valid_username`, `copy_authorized_keys`, `maybe_create_new_user`; a source-guard so tests can source the file without executing `main`.

- [ ] **Step 1: Add guard-test rules (failing first)**

Append to `tests/ubuntu-config.bash` (before the unit-test invocation added in Task 1):

```bash
# bootstrap new-user step: prompts must use /dev/tty (stdin is detached),
# handoff must be guarded and terminal, and sourcing must not execute main.
assert_contains 'DOTF_BOOTSTRAP_HANDOFF' "bootstrap.sh"
assert_contains 'adduser "\$username" </dev/tty' "bootstrap.sh"
assert_contains 'BASH_SOURCE\[0\]}" == "\$0"' "bootstrap.sh"
assert_no_pattern 'cp ~/.ssh/authorized_keys|cp "\$HOME/.ssh/authorized_keys"' "bootstrap.sh"

# username validation + symlink rejection are testable without mutating anything
if ! ( . "$ROOT/bootstrap.sh"
       dotf_valid_username alice &&
       ! dotf_valid_username 'Bad User' &&
       ! dotf_valid_username '' &&
       ! dotf_valid_username '1abc' ); then
  fail "bootstrap.sh dotf_valid_username does not enforce ^[a-z_][a-z0-9_-]*\$"
fi
```

Run: `bash tests/ubuntu-config.bash` — Expected: FAIL (functions and guard missing; sourcing currently *executes* `main`, which the source-guard fixes).

- [ ] **Step 2: Implement in `bootstrap.sh`**

Insert above `main()`:

```bash
dotf_valid_username() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]*$ ]]
}

# Hardened key copy: resolve home/group from the system, never follow or
# overwrite through symlinks, install with exact modes/ownership.
copy_authorized_keys() {
  local username="$1" home group src="$HOME/.ssh/authorized_keys"
  if [[ ! -f "$src" ]]; then
    echo "  !! no $src to copy — set up SSH access for '$username' manually."
    return 0
  fi
  home="$(getent passwd "$username" | cut -d: -f6)"
  group="$(id -gn "$username")"
  if [[ -z "$home" || -z "$group" ]]; then
    echo "  !! cannot resolve home/group for '$username'; skipping key copy." >&2
    return 0
  fi
  if [[ -L "$home/.ssh" || -L "$home/.ssh/authorized_keys" ]]; then
    echo "  !! $home/.ssh contains symlinks; refusing to copy keys." >&2
    return 0
  fi
  sudo install -d -m 700 -o "$username" -g "$group" "$home/.ssh"
  sudo install -m 600 -o "$username" -g "$group" "$src" "$home/.ssh/authorized_keys"
  echo "  -> authorized_keys copied to $home/.ssh/"
}

# Optional new-user creation + total handoff. One-shot: the re-exec'd copy
# runs with DOTF_BOOTSTRAP_HANDOFF=1 and skips this entirely. The parent
# exits right after the handoff — nothing installs for the original account.
maybe_create_new_user() {
  [[ "${DOTF_BOOTSTRAP_HANDOFF:-}" == "1" ]] && return 0
  [[ -r /dev/tty && -w /dev/tty ]] || return 0

  local answer username script_copy
  printf 'Create a new user for this setup? [y/N] ' > /dev/tty
  IFS= read -r answer < /dev/tty || return 0
  [[ "$answer" =~ ^[Yy]$ ]] || return 0

  while :; do
    printf 'Username: ' > /dev/tty
    IFS= read -r username < /dev/tty || return 0
    if ! dotf_valid_username "$username"; then
      echo "  !! invalid username (must match ^[a-z_][a-z0-9_-]*\$)" > /dev/tty
      continue
    fi
    if getent passwd "$username" >/dev/null 2>&1; then
      echo "  !! user '$username' already exists — existing accounts are never reused; pick a new name." > /dev/tty
      continue
    fi
    break
  done

  echo "==> Creating user '$username' (you will set their password)"
  sudo adduser "$username" </dev/tty >/dev/tty 2>&1
  sudo usermod -aG sudo "$username"
  copy_authorized_keys "$username"

  # The mktemp download is 0600 to this user; hand the new user a readable copy.
  script_copy="$(mktemp /tmp/dotf-bootstrap.XXXXXX)"
  cp "${BASH_SOURCE[0]}" "$script_copy"
  chmod 644 "$script_copy"

  echo "==> Handing installation off to '$username' (sudo will ask for THEIR password)"
  sudo -u "$username" -H env DOTF_BOOTSTRAP_HANDOFF=1 bash "$script_copy"
  exit $?
}
```

In `main()`, insert the call after the root check (line 126) and before the git install:

```bash
  maybe_create_new_user
```

Replace the last line `main "$@"` with a source-guard (the guard test sources
this file to unit-test `dotf_valid_username`):

```bash
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

- [ ] **Step 3: Verify**

Run: `bash tests/ubuntu-config.bash && bash -n bootstrap.sh`
Expected: PASS — including the pre-existing bootstrap rules (`main "\$@"` still present inside the source-guard; exactly one uncommented clone line; no new URLs).

- [ ] **Step 4: Stage and hand off**

```bash
git add bootstrap.sh tests/ubuntu-config.bash
```

---

### Task 11: Docs + final verification sweep

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`

- [ ] **Step 1: Update `AGENTS.md`**

- Repository Layout: add `setup/lib/profile.sh`, `setup/profile-select.sh`, `setup/skills.sh`, `tests/profile-lib-test.bash`, `home/git-dev`.
- Workflow: note profiles — state at `~/.config/dotf/profile`, `dotf profile` / `dotf skills`, manifests are group-sectioned (`## group: <name>`), new packages must go under the right group header.
- Verification block: extend the `bash -n` list with `setup/lib/profile.sh setup/profile-select.sh setup/skills.sh tests/profile-lib-test.bash`.
- Hard Constraints: add "state file is parsed, never sourced; manifest lines must sit under a `## group:` header (guard-enforced)".

- [ ] **Step 2: Update `README.md`**

Add a Profiles section: the three profiles, the group table (names + one-line contents), the new-user step, `dotf profile` / `dotf skills`, and that the bootstrap one-liner is unchanged.

- [ ] **Step 3: Full verification sweep**

```bash
bash tests/ubuntu-config.bash
bash -n setup.sh apply.sh doctor.sh bootstrap.sh setup/install-tools.sh \
  setup/tools/installers.sh setup/lib/profile.sh setup/profile-select.sh \
  setup/skills.sh tests/ubuntu-config.bash tests/profile-lib-test.bash \
  home/dotf/.local/bin/dotf
zsh -n home/zsh/.zshrc home/zsh/.config/zsh/*.zsh
```
Expected: all pass.

- [ ] **Step 4: Stage and hand off**

```bash
git add AGENTS.md README.md
```

---

## Post-merge manual test matrix (fresh Ubuntu 24.04 VM/container — not automatable here)

Per spec §Testing: minimal / developer / custom+deps runs, each ± the new-user step; bootstrap re-run after a completed install (no re-prompt, clean verify); corrupted state file → hard error → `dotf profile` recovery; minimal shell sanity (`ls`, `cat`, `git log` all work with no eza/bat/delta installed).
