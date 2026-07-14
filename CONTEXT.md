# Ubuntu Server Dotfiles

Declarative development environment for headless Ubuntu 24.04 servers: manifests and stow
packages describe the desired state; idempotent scripts make a machine match it.

## Language

**Converge**:
Make the machine match the declared state (manifests + stow packages). Always safe to re-run.
_Avoid_: install, sync, setup (setup is the fresh-machine special case)

**Drift**:
Any difference between the machine's actual state and the declared state. Detected read-only;
never repaired by the detector.
_Avoid_: issues, out-of-date

**Bootstrap**:
Taking a brand-new Ubuntu server from nothing to a converged machine in one step, run by a
non-root sudo user.
_Avoid_: provision, init

**Dotfiles root**:
The clone of this repo on a machine. Canonically `~/.dotfiles` on servers; may live elsewhere
(tools must discover it, not assume it).
_Avoid_: dotfiles dir, install dir

**Stow package**:
One directory under `home/` mirroring paths relative to `$HOME`, linked into place as a unit.
_Avoid_: module, config dir

**Manifest**:
A declarative list of packages for one package manager (one name per line, `#` comments).
The single source of truth — software not in a manifest doesn't exist.
_Avoid_: package list, requirements

**Fresh mode**:
First-time converge on a machine with pre-existing config files, which are adopted into the repo
rather than treated as conflicts.

**Guard**:
The static test that rejects forbidden patterns (macOS artifacts, nvm, secrets) and requires
load-bearing ones before a commit lands.
_Avoid_: lint, static test

**Veneer**:
A convenience command that only delegates to the existing scripts and never grows its own
converge logic (`dotf` is one).
_Avoid_: wrapper, facade
