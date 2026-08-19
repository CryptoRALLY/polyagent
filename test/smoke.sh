#!/usr/bin/env bash
# Smoke tests for the `agent` switchboard script.
#
# Exercises the safe, non-interactive commands (init, profiles, status,
# handoff, and validation errors) against isolated fake
# AGENT_SWITCHBOARD_HOME directories. Does NOT exercise login/start/switch's
# happy path -- that execs into tmux and a real, authenticated Codex/Claude
# CLI, which CI doesn't have. See CONTRIBUTING.md for how to test that part
# by hand.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
agent="$repo_root/agent"

pass=0
fail=0
fail_names=()

ok()  { printf 'ok   - %s\n' "$1"; ((++pass)); }
bad() { printf 'FAIL - %s\n' "$1"; ((++fail)); fail_names+=("$1"); }

expect_success() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

expect_failure() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then bad "$desc"; else ok "$desc"; fi
}

expect_output_contains() {
  local desc="$1" needle="$2"; shift 2
  local out
  out="$("$@" 2>&1)" || true
  if [[ "$out" == *"$needle"* ]]; then ok "$desc"; else bad "$desc (output: $out)"; fi
}

section() { printf '\n--- %s ---\n' "$1"; }

### Default profile list ####################################################

section "default profile list"
tmp1="$(mktemp -d)"
export AGENT_SWITCHBOARD_HOME="$tmp1/home"
unset AGENT_SWITCHBOARD_PROFILES AGENT_SWITCHBOARD_HANDOFF_HOME

expect_success "init creates the app home" "$agent" init
for p in codex-1 codex-2 claude-1 claude-2; do
  expect_success "init creates profile dir: $p" test -d "$AGENT_SWITCHBOARD_HOME/profiles/$p"
done

expect_output_contains "profiles lists codex-1 as needing login" "codex-1" "$agent" profiles
expect_output_contains "profiles lists claude-2 as needing login" "claude-2" "$agent" profiles

expect_output_contains "status shows no active task before any handoff" "Active task: none" "$agent" status

handoff_file="$("$agent" handoff --task smoke-test --note 'smoke test note')"
expect_success "handoff writes a file" test -f "$handoff_file"
expect_output_contains "handoff file names the task" "Agent handoff: smoke-test" cat "$handoff_file"
expect_output_contains "handoff file carries the operator note" "smoke test note" cat "$handoff_file"

expect_failure "start rejects an unknown profile" "$agent" start bogus-profile
expect_failure "start rejects a nonexistent directory" "$agent" start codex-1 --dir /nonexistent/path/for/smoke/test

rm -rf "$tmp1"

### Custom / extended profile list ##########################################

section "custom profile list (AGENT_SWITCHBOARD_PROFILES)"
tmp2="$(mktemp -d)"
export AGENT_SWITCHBOARD_HOME="$tmp2/home"
export AGENT_SWITCHBOARD_PROFILES="codex-1 codex-2 codex-3 claude-1"

expect_success "init creates dirs for a custom profile list" "$agent" init
expect_success "init creates the extra codex-3 profile dir" test -d "$AGENT_SWITCHBOARD_HOME/profiles/codex-3"
expect_output_contains "profiles lists the custom codex-3 profile" "codex-3" "$agent" profiles
expect_failure "start rejects a profile outside the custom list" "$agent" start claude-2

rm -rf "$tmp2"
unset AGENT_SWITCHBOARD_PROFILES

### Summary ##################################################################

printf '\n%d passed, %d failed\n' "$pass" "$fail"
if ((fail > 0)); then
  printf 'Failed: %s\n' "${fail_names[*]}"
  exit 1
fi
