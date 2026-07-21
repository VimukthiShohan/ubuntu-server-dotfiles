---
title: One Command Turns a Fresh Ubuntu Server into a 24/7 AI Development Machine
published: false
description: How the developer profile in my dotfiles repo provisions a complete AI coding environment — Claude Code, Codex, opencode, skill frameworks, and the whole toolchain — on any fresh Ubuntu 24.04 server.
tags: ai, linux, ubuntu, productivity
canonical_url:
---

AI coding agents changed the shape of my development day. A session with Claude Code isn't a burst of typing anymore — it's a long-running conversation where the agent researches, implements, runs tests, and iterates while I check in. And that exposed the weakest link in my setup: **the laptop**. Close the lid, lose the session. Spotty café Wi-Fi, lose the session. Want the agent grinding through a migration overnight? The laptop stays open on the kitchen counter.

The fix is old and boring: do the work on a server, keep the sessions in tmux, connect from wherever you are. What was missing was the setup cost — a fresh VPS is a bare shell, and provisioning zsh, Neovim, Node, Rust, Docker, *and* the whole AI toolchain by hand is half a day of yak-shaving before the first prompt.

So I made it one command. This post is about the **developer profile** in [ubuntu-server-dotfiles](https://github.com/VimukthiShohan/ubuntu-server-dotfiles) (v1.3.0): what it installs, how the AI layer gets set up, and the actual 24/7 working pattern it enables. I covered the underlying GNU Stow + idempotent-bash machinery in [an earlier post](https://github.com/VimukthiShohan/ubuntu-server-dotfiles/blob/main/docs/blog/gnu-stow-dotfiles.md) — this one is about what it's *for*.

## The one command

On any fresh Ubuntu 24.04 server, as a non-root user with sudo:

```bash
f=$(mktemp) && curl -fsSL https://raw.githubusercontent.com/VimukthiShohan/ubuntu-server-dotfiles/main/bootstrap.sh -o "$f" && bash "$f"
```

(Download-then-run instead of `curl | bash`, so a truncated download can never execute a partial script.)

Two questions later, you're done:

1. **Create a new user for this setup?** — On a cloud image you land as `ubuntu` or `root`'s cousin. Answer `y`, name the user, and bootstrap creates it, gives it sudo, copies your `authorized_keys` over (hardened — refuses symlinks, uses `install` with exact modes), and hands the entire installation off to that account. Your daily-driver user never shares state with the cloud default.
2. **Select a profile** — this is the new part in v1.3.0:

```
Select a profile:
  1) minimal    — server essentials only
  2) developer  — everything (editor stack, runtimes, AI CLIs)
  3) custom     — essentials + groups you pick
Choice [1-3]: 2
```

Pick `2`, go make coffee. The choice is saved to `~/.config/dotf/profile`, so re-runs never re-ask.

## What "developer" actually installs

Everything, in dependency order, from plain-text manifests:

| Layer       | What you get                                                                              |
|-------------|-------------------------------------------------------------------------------------------|
| Shell       | zsh (login shell) + powerlevel10k, tmux + TPM, fzf, zoxide, direnv                        |
| Ergonomics  | ripgrep, fd, bat, eza, delta, btop, lazygit, yazi, gh, just, shellcheck                   |
| Editor      | Neovim from the official tarball (apt's 0.9 is too old), lua-language-server, tree-sitter |
| Runtimes    | Node via fnm, bun, pnpm, Rust via rustup, Go, Python + uv/pipx                            |
| Services    | Docker (enabled + your user in the group), postgres/redis clients                         |
| Cloud       | AWS CLI v2                                                                                |
| **AI CLIs** | **Claude Code, opencode, OpenAI Codex, rtk**                                              |

The AI row is the point. `claude`, `opencode`, and `codex` are installed by the same manifest discipline as everything else — official installers, guarded, idempotent. `rtk` (a token-optimizing CLI proxy for agent sessions) comes along via cargo.

Then the optional layer on top: **AI skill frameworks**. After the toolchain lands, `dotf skills` offers a picker:

```
AI skill frameworks (comma-separated numbers, empty for none):
  1) SuperClaude Framework
  2) Superpowers (obra)
  3) mattpocock/skills
  4) Graphify
  5) react-devtools (Callstack)
  6) Callstack agent-skills (React Native)
```

Each installs user-globally and unattended-safe (that took real debugging — one CLI liked to stall on an interactive scope prompt). Re-running is always safe; the installer re-runs each framework's official install command rather than presence-skipping, so updates come for free.

## The 24/7 working pattern

Here's an actual session, field-tested on a fresh EC2 instance running Ubuntu 24.04.

**Once, at provision time:**

```bash
# the bootstrap one-liner above, answer y → username → profile 2
# ...coffee...
ssh dev@your-server       # as the new user
claude auth login         # authenticate the agents once per machine
gh auth login
```

**Every working session after that:**

```bash
ssh dev@your-server
tmx                       # tmux workspace bootstrapper, ships with the repo
claude                    # start the agent on whatever you're building
```

`tmx` (stowed alias for `scripts/tmx/main.sh`) spins up my named tmux dev workspace — editor pane, agent pane, shell. The part that changes everything:

```
Ctrl-Space d              # detach — the agent keeps working
```

(`Ctrl-Space` is the prefix this repo's `.tmux.conf` ships; stock tmux uses `Ctrl-b`.)

Close the laptop. The session doesn't care. Claude Code is still running the test suite, opencode is still mid-refactor. Reattach from anywhere:

```bash
ssh dev@your-server -t tmux attach
```

From the same laptop at home, from a different machine at the office, from an SSH client on your phone while waiting in line. The session is exactly where you left it — scrollback, agent context, running processes, all of it. Kick off a long agent task in the evening, check the result over breakfast.

**The phone, without SSH: Remote Control.** SSH-from-a-phone works, but a terminal on a 6-inch screen is an act of stubbornness. Claude Code has a better answer — start the agent with Remote Control enabled:

```bash
claude --remote-control
```

The session pairs with the Claude app on your phone, and you drive it from there: read what the agent did, answer its questions, approve the next step, send follow-up prompts — a native mobile UI instead of a squinted-at terminal. Run it inside the tmux workspace and you get both worlds: the full terminal when you're at a keyboard, the app when you're not. This is what makes the always-on server click for agent work — the agent asks "should I refactor these call sites too?" while you're out for lunch, and you answer from your pocket instead of losing the afternoon's momentum. Sessions are named by hostname by default, so if you run several servers, each shows up distinctly in the app.

And keeping the machine current is two commands:

```bash
dotf update    # git pull --ff-only, then converge
dotf doctor    # read-only drift check — exits 1 if anything's off
```

## Sizing the server

Opinionated and brief: **2 vCPUs and 4 GB RAM is the comfortable floor** for the developer profile. The single heaviest step is compiling yazi from source via cargo (a few minutes on 2 vCPUs); everything else is downloads. 2 GB works if you add swap, but the first `cargo install` will make you regret it. Disk: 25 GB+ once Docker images enter the picture. The AI CLIs themselves are lightweight — the *agents'* heavy lifting happens on the provider's side, not your box.

Don't overprovision for the agents; provision for *your* builds and containers.

## What the repo deliberately doesn't set up

No SSH private keys, no GitHub auth state, no API tokens — ever. The repo is public; machine identity is not, and a static guard test fails the build if a forbidden pattern sneaks into a tracked file. Authentication happens exactly once per machine, by you:

- `claude auth login` / `codex` first-run auth for the agents
- `gh auth login` for GitHub
- `~/.gitconfig.local` for git identity, `~/.config/zsh/local.zsh` for machine-local env — both untracked, both included automatically by the stowed configs

This is also why the new-user step matters: your AI development identity lives in a clean account you created, not in whatever the cloud image shipped.

## FAQ

**Why a server instead of just running agents on my laptop?**
Persistence and symmetry. Agent sessions are long-lived; laptops aren't. A server gives every device you own — laptop, desktop, phone — the same view of the same session: tmux for terminals, `claude --remote-control` for the Claude app. Suspend/resume, network switching, and "I need to leave now" stop being session-killers.

**Why not Codespaces / devcontainers?**
Those are per-project workspaces that spin down; this is a persistent *machine* that's yours. Different tools. I want tmux sessions that survive for weeks, Docker services that stay up, and cron running `dotf doctor`. Also: a plain VPS is provider-agnostic and often cheaper than always-on cloud IDEs.

**What if I don't want the full developer profile?**
That's what profiles are for. `minimal` gives you a working shell + git + the `dotf` CLI on boxes that don't need more. `custom` lets you pick groups — dependencies resolve automatically (picking `nvim` pulls in `build` and `node`; the picker shows each group's contents so you know what you're getting).

**Is re-running safe?**
Yes — that's the core design constraint. `apply.sh` converges: every step checks before it acts. Bootstrap refuses to touch a `~/.dotfiles` that isn't this repo, verifies the clone matches upstream before executing anything, and re-asks nothing you've already answered.

**Can I use this repo directly?**
Yes — clone it, gut my configs, keep the skeleton. The manifests and profile machinery don't care whose dotfiles are in `home/`.

---

The complete setup is at [github.com/VimukthiShohan/ubuntu-server-dotfiles](https://github.com/VimukthiShohan/ubuntu-server-dotfiles), released as [v1.3.0](https://github.com/VimukthiShohan/ubuntu-server-dotfiles/releases/tag/v1.3.0). One command, one coffee, and every device you own is a thin client to a development machine that never sleeps.
