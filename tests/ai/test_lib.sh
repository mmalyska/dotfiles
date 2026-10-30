#!/usr/bin/env bash
# shellcheck disable=SC2016  # snippets passed to run() are intentionally single-quoted
# ai-lib.sh unit tests: pure functions, status file only under the throw-away HOME.
. "$(dirname "$0")/lib.sh"
LIB="$AI_ROOT/home/.chezmoitemplates/ai-lib.sh"

bash -n "$LIB" || _fail "bash -n"
! grep -qF "{{" "$LIB" || _fail "ai-lib.sh must not contain template delimiters (it is included as a template)"
if command -v shellcheck >/dev/null; then shellcheck -s bash "$LIB" || _fail "shellcheck"; else echo "  NOT RUN shellcheck (not installed)"; fi

T=$(new_tmp)
REAL_HOME_SNAP=$(find "${AI_REAL_HOME:-/nonexistent}/.local/state/ai-workflow" -type f 2>/dev/null | sort | sha256sum)

# run <snippet>: fresh shell with the library, HOME and state dir inside $T.
run() { HOME="$T/home" XDG_STATE_HOME='' bash -c ". '$LIB'; $1" 2>&1; }
status() { cat "$T/home/.local/state/ai-workflow/$1.status"; }

# ai_have
run 'ai_have nonexistent_cmd_xyz' >/dev/null && _fail "ai_have nonexistent returned 0"
run 'ai_have bash' >/dev/null || _fail "ai_have bash returned non-zero"

# ai_soft: returns 0, counts the failure, logs WARN, runs the command in the current shell
out=$(run 'ai_soft "step x" -- false; echo "rc=$? fails=$AI_FAILS"; ai_soft ok -- true; echo "fails=$AI_FAILS"')
assert_contains "ai_soft rc" "$out" "rc=0 fails=1"
assert_contains "ai_soft ok does not count" "$out" "fails=1"
assert_contains "ai_soft WARN" "$out" "[ai-workflow] WARN step x failed"

# ai_summary with failures: DONE line, exit 0, partial status
out=$(run 'AI_FAILS=2; AI_ACCEPTED_SHA=abc; ai_summary claude; echo "rc=$?"')
assert_contains "summary line" "$out" "[ai-workflow] DONE claude fails=2"
assert_contains "summary rc" "$out" "rc=0"
assert_contains "partial" "$(status claude)" "result=partial"
assert_contains "fails" "$(status claude)" "fails=2"
assert_contains "sha" "$(status claude)" "accepted_sha=abc"
assert_contains "time" "$(status claude)" "time=20"

# ai_summary clean -> ok; after SKIP -> skipped
run 'ai_summary codex' >/dev/null
assert_contains "ok" "$(status codex)" "result=ok"
assert_contains "ok fails" "$(status codex)" "fails=0"
out=$(run 'ai_log SKIP "no cli"; ai_summary skipme; echo rc=$?')
assert_contains "skip log" "$out" "[ai-workflow] SKIP no cli"
assert_contains "skip rc" "$out" "rc=0"
assert_contains "skipped" "$(status skipme)" "result=skipped"

# ai_status_write directly, XDG_STATE_HOME honoured
HOME="$T/h2" XDG_STATE_HOME="$T/xdg" bash -c ". '$LIB'; ai_status_write claude partial 3"
assert_contains "xdg status" "$(cat "$T/xdg/ai-workflow/claude.status")" "result=partial"
[ ! -e "$T/h2" ] || _fail "HOME written although XDG_STATE_HOME set"

# ai_marketplace_head
git init -q "$T/mk" && git -C "$T/mk" -c user.email=a@b -c user.name=n commit -q --allow-empty -m x
assert_eq "head" "$(run "ai_marketplace_head '$T/mk'")" "$(git -C "$T/mk" rev-parse HEAD)"
assert_eq "head empty" "$(run "ai_marketplace_head '$T/none'")" ""

# real HOME untouched
assert_eq "real HOME state" \
    "$(find "${AI_REAL_HOME:-/nonexistent}/.local/state/ai-workflow" -type f 2>/dev/null | sort | sha256sum)" "$REAL_HOME_SNAP"
