# Contributing

`polyagent` is a single Bash script (`agent`). Keep it that way unless there's a
strong reason not to — no build step, no dependency manager, easy to read in one
sitting.

## Before you open a PR

```bash
bash -n agent          # syntax check
shellcheck agent        # static analysis
bash test/smoke.sh      # functional smoke tests
```

All three run in CI on every push and PR; a red check means don't merge yet.

`test/smoke.sh` covers everything that's safe to test without a real,
authenticated Codex or Claude install: `init`, `profiles`, `status`,
`handoff`, and the validation errors in `start`/`switch` (unknown profile,
missing directory). It deliberately does **not** exercise the happy path of
`login`, `start`, or `switch` — those `exec` into tmux and a real provider
CLI, which CI doesn't have.

If your change touches `login`, `run_profile`, or `start_or_switch`, test the
happy path by hand against a real signed-in profile before submitting:

```bash
AGENT_SWITCHBOARD_HOME=/tmp/polyagent-test ./agent init
AGENT_SWITCHBOARD_HOME=/tmp/polyagent-test ./agent login codex-1
AGENT_SWITCHBOARD_HOME=/tmp/polyagent-test ./agent start codex-1 --task smoke --dir /tmp
# in another shell, verify the handoff record and tmux session look right, then:
AGENT_SWITCHBOARD_HOME=/tmp/polyagent-test ./agent switch claude-1 --task smoke --note 'testing'
```

Point `AGENT_SWITCHBOARD_HOME` at a throwaway directory so you don't touch
your real profile credentials or handoff history.

## Code style

- `set -euo pipefail`, and keep it that way — don't add code that only works
  by accident under lenient error handling.
- Quote every variable expansion. `shellcheck` will catch most lapses.
- New profiles are data, not code: the profile list comes from
  `AGENT_SWITCHBOARD_PROFILES` (or the `codex-1 codex-2 claude-1 claude-2`
  default) and any `codex-*`/`claude-*` name works via `provider_for()`. Don't
  hardcode profile names or a fixed count of four anywhere new.
- Prefer extending the existing `probe_usage_*`, `is_logged_in`, and
  `provider_for` case statements over adding a third provider's worth of
  special-casing scattered through the file — if you're adding a new
  provider, those three functions are the seam.

## Security-sensitive defaults

`run_profile()` launches both providers with per-command approval disabled
(Codex `--ask-for-approval never --sandbox danger-full-access`, Claude
`--permission-mode bypassPermissions`). That's intentional — see the
README's "Approval mode" section — but it means a bug here has real blast
radius (arbitrary command execution with the user's full shell authority).
Changes to `run_profile()`, `login()`, or anything touching `CODEX_HOME`/
`CLAUDE_CONFIG_DIR` isolation deserve extra scrutiny and a clear explanation
of what changed and why.

## Reporting issues

Open a GitHub issue with your OS, Bash version (`bash --version`), and which
provider CLI(s) and version(s) you're using. For anything involving actual
credentials or account details, describe it — don't paste it.
