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
check_not "media merged into ergonomics, no longer a group" dotf_known_group media
check_eq "state file honors XDG_CONFIG_HOME" "$(dotf_state_file)" "$tmpdir/config/dotf/profile"
check_eq "core stow packages" "$(dotf_group_stow_packages core)" "zsh git tmux dotf"
check_eq "ergonomics stow packages" "$(dotf_group_stow_packages ergonomics)" "eza btop neofetch gh git-dev lazygit"

# --- closure ---
check_eq "closure adds deps: nvim" "$(dotf_closure nvim)" "build,node,nvim"
check_eq "closure dedups: nvim,rust,node" "$(dotf_closure "nvim,rust,node")" "build,node,nvim,rust"
check_eq "closure of ai-clis pulls node+rust" "$(dotf_closure ai-clis)" "ai-clis,build,node,rust"
check_eq "closure of ergonomics pulls toolchains" "$(dotf_closure ergonomics)" "build,ergonomics,go-tools,rust"
check_eq "closure of empty is empty" "$(dotf_closure "")" ""

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
( dotf_load_state_ro 2>/dev/null; dotf_group_active cloud ) \
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
printf '## group: core\nsudo\n## group: services\nredis-tools\n' > "$mf"
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
