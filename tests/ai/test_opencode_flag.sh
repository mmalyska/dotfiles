#!/usr/bin/env bash
# T12: ai_opencode is only a flag. true vs false renders the same settings and installers, produces the same CLI calls
# and the same managed files; the doctor shows one informational line and nothing else changes.
. "$(dirname "$0")/lib.sh"

T=$(new_tmp)
OFF=core-linux; ON=core-opencode-linux
assert_eq "fixture differs only in ai_opencode" "$(diff <(cat "$FIXTURES/$OFF.toml") <(cat "$FIXTURES/$ON.toml") | grep -c '^[<>]')" "2"
assert_contains "fixture is on" "$(cat "$FIXTURES/$ON.toml")" "ai_opencode = true"

# settings.json: identical
assert_eq "settings.json" "$(render $ON home/dot_claude/settings.json.tmpl)" "$(render $OFF home/dot_claude/settings.json.tmpl)"

# installers: identical rendering, identical calls on a fresh state
for tpl in home/.chezmoiscripts/ai/run_onchange_after_100-claude-plugins.sh.tmpl home/.chezmoiscripts/ai/run_onchange_after_110-codex-plugins.sh.tmpl; do
    n=$(basename "$tpl" .sh.tmpl)
    for f in $OFF $ON; do PATH=$STUBS:$BASE_PATH "$CHEZMOI" --source "$AI_ROOT" --config "$FIXTURES/$f.toml" execute-template < "$AI_ROOT/$tpl" > "$T/$n.$f.sh"; done
    cmp -s "$T/$n.$OFF.sh" "$T/$n.$ON.sh" || _fail "$n renders differently with ai_opencode=true"
    for f in $OFF $ON; do
        HOME="$T/home.$f.$n" PATH="$STUBS:$BASE_PATH" AI_TEST_LOG="$T/$n.$f.log" bash "$T/$n.$f.sh" >/dev/null 2>&1 || _fail "$n ($f) failed"
    done
    cmp -s "$T/$n.$OFF.log" "$T/$n.$ON.log" || _fail "$n makes different CLI calls with ai_opencode=true"
    [ -s "$T/$n.$ON.log" ] || _fail "$n made no calls at all (test would be vacuous)"
    ! grep -qi opencode "$T/$n.$ON.log" || _fail "$n calls opencode"
done

# managed files and scripts: identical
for f in $OFF $ON; do "$CHEZMOI" --source "$AI_ROOT" --config "$FIXTURES/$f.toml" --destination "$T/dest" managed --include=files,scripts,dirs > "$T/managed.$f"; done
cmp -s "$T/managed.$OFF" "$T/managed.$ON" || _fail "managed targets differ with ai_opencode=true"
! grep -qi opencode "$T/managed.$ON" || _fail "a managed target mentions opencode"

# doctor: same except the flag constant, and the informational row appears only when on
for f in $OFF $ON; do "$CHEZMOI" --source "$AI_ROOT" --config "$FIXTURES/$f.toml" execute-template < "$AI_ROOT/home/dot_local/bin/executable_ai-workflow-doctor.tmpl" > "$T/doctor.$f.sh"; done
assert_eq "doctor differs only in USE_OPENCODE" "$(diff "$T/doctor.$OFF.sh" "$T/doctor.$ON.sh" | grep '^[<>]')" "$(printf '< USE_OPENCODE=false\n> USE_OPENCODE=true')"
mkdir -p "$T/h"
out_off=$(env HOME="$T/h" PATH="$BASE_PATH" bash "$T/doctor.$OFF.sh" 2>&1)
out_on=$(env HOME="$T/h" PATH="$BASE_PATH" bash "$T/doctor.$ON.sh" 2>&1)
assert_contains "doctor off row" "$out_off" "[opencode] disabled"
assert_not_contains "doctor off has no spike line" "$out_off" "spike not implemented"
assert_contains "doctor on row" "$out_on" "[opencode] enabled"
assert_contains "doctor on spike line" "$out_on" "spike not implemented"
assert_eq "doctor otherwise identical" "$(printf '%s\n' "$out_on" | grep -v -e 'opencode' )" "$(printf '%s\n' "$out_off" | grep -v -e 'opencode')"

# the spike document exists and keeps its promises
D="$AI_ROOT/docs/workflow/opencode-spike.md"
doc=$(cat "$D")
for needle in "no installer" "v2.2.0" "AGENTS.md" "Skills" "Permissions and hooks" "Subagents" "Worktrees" "Installation through dotfiles" \
              "QUICK + SOLO" "STANDARD + HANDOFF" "REVIEW" "NOT RUN" "compatibility.md#opencode-manual-path-and-future-spike"; do
    assert_contains "spike doc: $needle" "$doc" "$needle"
done
assert_not_contains "no checked item" "$doc" "- [x]"
