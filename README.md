# polyagent

A terminal launcher for people running **multiple AI coding-agent CLIs** (Codex, Claude Code) across **multiple accounts** (personal + work) at the same time, without them stepping on each other.

## The problem

If you use both Codex and Claude Code, and you have separate personal and work subscriptions/workspaces for either or both, you end up with:

- **Credential collisions.** Both CLIs default to one config/auth directory (`~/.codex`, `~/.claude`). Logging into a second account usually means logging out of the first, or fighting with shell profiles and env vars every time you switch.
- **Lost context on handoff.** You start diagnosing something with Codex, decide Claude should implement the fix (or vice versa), and there's no clean record of what the first agent found, what the working tree looked like, or what the second agent still needs to check.
- **Session sprawl.** Long-running agent sessions in a terminal get lost the moment you close the window or disconnect, especially over SSH.
- **No visibility into which account is "hot".** With auto-approve/bypass-permission modes on (which you often want for long agent runs), it's easy to lose track of which of four accounts a given terminal is about to burn against.

None of this is hard individually. It's just enough friction that people either avoid running multiple profiles at once, or do it carelessly (shared credentials, no handoff trail, no idea what's signed in where).

## What it solves

`agent` is a single Bash script that gives each profile — `codex-personal`, `codex-work`, `claude-personal`, `claude-work` — its own fully isolated credential directory, then wraps starting, switching, and tracking those sessions in one interactive menu.

- **Isolated auth per profile.** Each profile gets its own `CODEX_HOME` / `CLAUDE_CONFIG_DIR`, mode `0700`. Logging into `codex-work` never touches `codex-personal`'s session. No credentials are ever written to the script's own directory.
- **Persistent sessions via tmux.** `agent start <profile>` opens (or reattaches) a dedicated tmux session per `(profile, task)`. Detach with `Ctrl-b d`, come back later, even over SSH from a different machine.
- **Recorded handoffs.** `agent switch <profile> --note '...'` writes a private Markdown record — git root, HEAD commit, working-tree status, your note — before attaching the destination profile. The receiving agent is pointed at that file, so context survives the switch instead of getting lost.
- **One interactive menu, `agent`.** Start/continue work, hand off to another account, set the active task/directory, sign in, or check status — without needing to remember subcommands.
- **Deliberate, not automatic, usage checks.** Neither Codex nor Claude exposes live quota over just sitting there, and interactive sessions don't print a cost summary at exit. `agent usage` makes one small, real, billed call per signed-in profile on request and caches the result, so the profile picker can show last-known cost/model — without ever spending money automatically.
- **Auto-approve by default, on purpose.** Both CLIs launch with per-command approval prompts disabled (Codex `--ask-for-approval never --sandbox danger-full-access`, Claude `--permission-mode bypassPermissions`), because that's the point of a long-running unattended agent session. This is a real, sharp default — see [Approval mode](#approval-mode) below.

## Install

```bash
git clone https://github.com/CryptoRALLY/polyagent.git
ln -s "$(pwd)/polyagent/agent" ~/.local/bin/agent   # anywhere on your PATH works
agent init
```

Sign in once per isolated profile. In each provider's login flow, pick the account/workspace you want that profile permanently bound to:

```bash
agent login codex-personal
agent login codex-work
agent login claude-personal
agent login claude-work
```

Codex login uses device authentication (`codex login --device-auth`) rather than a browser localhost callback, so it also works cleanly when the terminal session is on a remote/headless machine and the browser is on your local computer.

You don't need all four profiles — only sign in to the ones you actually use. `agent status` shows which are ready.

## Daily use

```bash
agent
```

opens the menu:

```
1) Start or continue work
2) Handoff and switch account/workspace
3) Set task and working directory
4) Sign in or refresh a profile
5) Check profile status
6) Refresh usage for all profiles (makes small real billed calls)
q) Quit
```

The same actions are available as subcommands, for scripting or SSH one-liners:

```bash
agent start codex-personal --task refactor-api --dir ~/projects/api
agent switch claude-work --task refactor-api --note 'Codex diagnosed the root cause; implement and test the fix.'
agent status
```

Only run one agent against a given working tree at a time — the tool doesn't lock or serialize file access for you.

## Usage/cost visibility

```bash
agent usage
```

makes one small, real, billed call to each signed-in profile (a trivial "reply with exactly: ok" prompt) to read back the model and cost the provider reports, and caches it. Claude reports exact USD cost; Codex/ChatGPT-plan profiles currently only expose token counts, not a dollar figure. This never runs automatically — you have to ask for it, every time, the same way the tool never picks an account for you automatically.

## Approval mode

By default, sessions launch with no per-command confirmation:

- Codex: `--ask-for-approval never --sandbox danger-full-access`
- Claude: `--permission-mode bypassPermissions`

This means an active `agent` session has your full shell-level authority — the agent can run any command, edit any file it can reach, without asking first. That's the tradeoff for a long-running, hands-off agent session; it is **not** a safe default for untrusted prompts or untrusted repos. If you want per-command approval, edit `run_profile()` in the script and drop those flags for the profiles where you want it.

## Configuration

Two environment variables, both optional:

| Variable | Default | Purpose |
|---|---|---|
| `AGENT_SWITCHBOARD_HOME` | `~/.local/share/agent-switchboard` | Where profile credentials, session state, and cached usage data live. |
| `AGENT_SWITCHBOARD_HANDOFF_HOME` | `$AGENT_SWITCHBOARD_HOME/handoffs` | Where handoff Markdown records are written. Point this at a shared/synced directory if multiple machines or agents should see the same handoff trail. |
| `AGENT_SWITCHBOARD_RESUME_NOTE` | a generic reminder to read your project's shared instructions file | Free-text note appended to every handoff record, e.g. project-specific rules of engagement. |

## Requirements

- `bash`, `tmux`, `python3` (used only to parse the small JSON usage responses)
- [Codex CLI](https://github.com/openai/codex) and/or [Claude Code](https://github.com/anthropics/claude-code), whichever profiles you actually use

## License

MIT — see [LICENSE](LICENSE).
