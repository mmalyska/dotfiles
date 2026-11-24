#!/usr/bin/env bash
# ~/.codex/hooks.json: the Codex SessionStart hook that runs `ai-workflow-doctor --hook`. Managed only where it can work
# (not on Windows, not with ai_codex=false), valid, and a no-op without the doctor.
. "$(dirname "$0")/lib.sh"

SRC=$AI_ROOT/home/dot_codex/hooks.json
python3 -I -m json.tool "$SRC" >/dev/null || _fail "hooks.json is not valid JSON"
cmd=$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1]))["hooks"]["SessionStart"]; assert len(d)==1 and len(d[0]["hooks"])==1; print(d[0]["hooks"][0]["command"])' "$SRC") \
    || _fail "hooks.json must hold exactly one SessionStart hook"
assert_contains "runs the doctor in hook mode" "$cmd" "ai-workflow-doctor --hook"
assert_contains "guarded when the doctor is absent" "$cmd" "[ -x ~/.local/bin/ai-workflow-doctor ]"
assert_contains "never fails the session" "$cmd" "|| true"
claude_cmd=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["SessionStart"][0]["hooks"][0]["command"])' "$AI_ROOT/tests/ai/golden/core.settings.json") \
    || _fail "cannot read the Claude hook from the golden settings"
assert_eq "same command as the Claude hook" "$cmd" "$claude_cmd"

# which hosts get it
managed() { "$CHEZMOI" --source "$AI_ROOT" --config "$FIXTURES/$1.toml" --destination "$T/dest.$1" managed --include files 2>/dev/null; }
T=$(new_tmp)
for f in core-linux minimal-linux extended-linux legacy-linux core-noclaude-linux; do
    assert_contains "$f gets the hook" "$(managed "$f")" ".codex/hooks.json"
done
assert_not_contains "ai_codex=false gets no hook" "$(managed core-nocodex-linux)" ".codex/hooks.json"
pats=$("$AI_ROOT/tests/ai/render_ignore.sh" windows false) || _fail "render_ignore windows"
assert_contains "windows ignores the hook" "$pats" ".codex/hooks.json"
pats=$("$AI_ROOT/tests/ai/render_ignore.sh" linux false) || _fail "render_ignore linux"
assert_not_contains "linux does not ignore the hook" "$pats" ".codex/hooks.json"

# run the registered command the way a shell would: silent without the doctor, the doctor's output with it
H="$T/home"; mkdir -p "$H/.local/bin"
OUT=$(HOME="$H" PATH="$BASE_PATH" sh -c "$cmd" 2>&1); RC=$?
assert_eq "no doctor: rc" "$RC" "0"; assert_eq "no doctor: output" "$OUT" ""
printf '#!/bin/sh\necho "{\\"systemMessage\\":\\"x\\"}"\n' > "$H/.local/bin/ai-workflow-doctor"; chmod +x "$H/.local/bin/ai-workflow-doctor"
OUT=$(HOME="$H" PATH="$BASE_PATH" sh -c "$cmd" 2>&1); RC=$?
assert_eq "with doctor: rc" "$RC" "0"; assert_contains "with doctor: output" "$OUT" '"systemMessage"'
printf '#!/bin/sh\nexit 3\n' > "$H/.local/bin/ai-workflow-doctor"
HOME="$H" PATH="$BASE_PATH" sh -c "$cmd" >/dev/null 2>&1; assert_eq "a failing doctor does not fail the hook" "$?" "0"
:
