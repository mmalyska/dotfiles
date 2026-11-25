#!/usr/bin/env bash
# ai-workflow-doctor --quiet / --hook: silent when nothing is pending, one line per thing to do otherwise, always exit 0;
# and the pending section of the full report. Uses a real origin and clone for the "merged but not pulled" case.
. "$(dirname "$0")/lib.sh"

T=$(new_tmp)
DOCTOR_TPL=home/dot_local/bin/executable_ai-workflow-doctor.tmpl
"$CHEZMOI" --source "$AI_ROOT" --config "$FIXTURES/core-linux.toml" execute-template < "$AI_ROOT/$DOCTOR_TPL" > "$T/doctor.tpl.sh"

ids=(); for p in "${OWN_IDS[@]}"; do ids+=("$p@$OWN"); done
write_state "$T/state-ok.json" "${ids[@]}"
write_codex_state "$T/codex-ok.json" "${ids[@]}"
cat "$T/state-ok.json" "$T/codex-ok.json" > "$T/both-ok.json"

# marketplace checkouts whose HEAD is the accepted sha (patched into the rendered doctor, as in test_doctor)
H="$T/home"; MK="$H/.claude/plugins/marketplaces/$OWN"
git init -q "$MK" && git -C "$MK" -c user.email=a@b -c user.name=n commit -q --allow-empty -m x
HEAD_SHA=$(git -C "$MK" rev-parse HEAD)
mkdir -p "$H/.codex" "$H/.local/state/ai-workflow"
printf '[marketplaces.%s]\nsource_type = "git"\nref = "%s"\n' "$OWN" "$HEAD_SHA" > "$H/.codex/config.toml"
for h in claude codex; do printf 'result=ok\nfails=0\naccepted_sha=%s\ntime=x\n' "$HEAD_SHA" > "$H/.local/state/ai-workflow/$h.status"; done

# a dotfiles source with a remote: origin (bare) and the clone the doctor reads
pin() { # <dir> <sha> <tag>: write the pin file in a working tree
    mkdir -p "$1/.chezmoidata"
    printf 'ai_workflow:\n  marketplace:\n    own:\n      accepted_sha: %s\n      # Tag of the accepted revision.\n      accepted_tag: %s\n' "$2" "$3" > "$1/.chezmoidata/ai-workflow.yaml"
}
git_in() { git -C "$1" -c user.email=a@b -c user.name=n "${@:2}"; }
SEED="$T/seed"; mkdir -p "$SEED"; git init -q -b main "$SEED"
pin "$SEED" "$HEAD_SHA" ai-workflow-v1.0.0; git_in "$SEED" add -A; git_in "$SEED" commit -q -m pin
git clone -q --bare "$SEED" "$T/origin.git"; git clone -q "$T/origin.git" "$T/src"
push_pin() { # <sha> <tag>: a new pin on origin, through the seed repository
    pin "$SEED" "$1" "$2"; git_in "$SEED" commit -q -am "pin $2"; git_in "$SEED" push -q "$T/origin.git" main
}

sed "s#^ACCEPTED_SHA=.*#ACCEPTED_SHA=\"$HEAD_SHA\"#; s#^SOURCE_DIR=.*#SOURCE_DIR=\"$T/src\"#" "$T/doctor.tpl.sh" > "$T/doctor.sh"
bash -n "$T/doctor.sh" || _fail "bash -n"
age_stamp() { # [minutes, default 420]: make the fetch stamp that old
    python3 -I -c 'import os,sys,time; t=time.time()-float(sys.argv[2])*60; os.utime(sys.argv[1],(t,t))' "$H/.local/state/ai-workflow/source-fetch" "${1:-420}"
}
run() { # <args...>: sets OUT and RC; STUB_STATE from $STATE
    OUT=$(env -u XDG_STATE_HOME -u CLAUDE_CONFIG_DIR -u CODEX_HOME HOME="$H" PATH="$STUBS:$BASE_PATH" STUB_STATE="$STATE" bash "$T/doctor.sh" "$@" 2>&1); RC=$?
}
valid_json() { printf '%s' "$1" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(d["systemMessage"]); assert d["hookSpecificOutput"]["hookEventName"]=="SessionStart"; assert d["hookSpecificOutput"]["additionalContext"]'; }

# (1) nothing pending: silent, exit 0, in both modes; the full report stays OK
STATE="$T/both-ok.json"
run --quiet; assert_eq "(1) quiet rc" "$RC" "0"; assert_eq "(1) quiet output" "$OUT" ""
run --hook;  assert_eq "(1) hook rc" "$RC" "0";  assert_eq "(1) hook output" "$OUT" ""
run --strict; assert_eq "(1) strict rc" "$RC" "0"; assert_not_contains "(1) no pending section" "$OUT" "[pending]"

# (2) an installed plugin behind the marketplace checkout
mkdir -p "$MK/plugins/git-workflows/.claude-plugin"
printf '{\n  "name": "git-workflows",\n  "version": "1.3.12"\n}\n' > "$MK/plugins/git-workflows/.claude-plugin/plugin.json"
cat > "$T/state-old.json" <<J
[
  {
    "id": "git-workflows@$OWN",
    "version": "1.3.11",
    "scope": "user",
    "enabled": true
  }
]
J
STATE="$T/state-old.json"
run --quiet; assert_eq "(2) rc" "$RC" "0"
assert_contains "(2) stale line" "$OUT" "git-workflows 1.3.11->1.3.12"
assert_contains "(2) command" "$OUT" "claude plugin update <name>@$OWN"
run --hook; assert_eq "(2) hook rc" "$RC" "0"
msg=$(valid_json "$OUT") || _fail "(2) hook output is not the expected JSON: $OUT"
assert_contains "(2) hook message" "$msg" "git-workflows 1.3.11->1.3.12"
run --strict; assert_eq "(2) strict rc" "$RC" "1"; assert_contains "(2) pending section" "$OUT" "[pending]"
# the same version is fine
STATE="$T/both-ok.json"; printf '{\n  "name": "git-workflows",\n  "version": "1.3.11"\n}\n' > "$MK/plugins/git-workflows/.claude-plugin/plugin.json"
STATE="$T/state-old.json"; run --quiet; assert_eq "(2) equal versions" "$OUT" ""

# (3) the source accepts another revision than the one this host runs (pulled, not applied)
STATE="$T/both-ok.json"
pin "$T/src" bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ai-workflow-v1.0.1
run --quiet; assert_contains "(3) source line" "$OUT" "The dotfiles source accepts claude-plugins bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
assert_contains "(3) command" "$OUT" "AI_WORKFLOW_UPGRADE=1 chezmoi apply"
git_in "$T/src" checkout -q -- .chezmoidata/ai-workflow.yaml

# (4) merged upstream, not pulled yet; the fetch runs once the stamp of an earlier run is old
rm -f "$H/.local/state/ai-workflow/source-fetch"
push_pin cccccccccccccccccccccccccccccccccccccccc ai-workflow-v9.9.9
run --quiet; assert_eq "(4) rc" "$RC" "0"
assert_contains "(4) upstream line" "$OUT" "accepted upstream (ai-workflow-v9.9.9)"
assert_contains "(4) command" "$OUT" "chezmoi git pull"
[ -e "$H/.local/state/ai-workflow/source-fetch" ] || _fail "(4) no fetch stamp"
run --hook; valid_json "$OUT" >/dev/null || _fail "(4) hook JSON: $OUT"

# (5) the fetch is throttled: a newer pin is not seen until the stamp is old
push_pin dddddddddddddddddddddddddddddddddddddddd ai-workflow-v9.9.10
run --quiet; assert_not_contains "(5) throttled" "$OUT" "v9.9.10"
age_stamp
run --quiet; assert_contains "(5) refetched" "$OUT" "ai-workflow-v9.9.10"

# (5b) the throttle is 30 minutes: a 20 minute old stamp still holds, a 40 minute old one fetches
push_pin eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee ai-workflow-v9.9.11
age_stamp 20
run --quiet; assert_not_contains "(5b) 20 minutes: still throttled" "$OUT" "v9.9.11"
age_stamp 40
run --quiet; assert_contains "(5b) 40 minutes: fetched" "$OUT" "ai-workflow-v9.9.11"

# (6) the full report never fetches or looks at the remote: with a fresh stamp removed, it makes no stamp
rm -f "$H/.local/state/ai-workflow/source-fetch"
run; [ ! -e "$H/.local/state/ai-workflow/source-fetch" ] || _fail "(6) the full report fetched"

# (7) pulled: the upstream line is gone, the apply line replaces it
git_in "$T/src" pull -q --ff-only
run --quiet; assert_not_contains "(7) no upstream line" "$OUT" "accepted upstream"
assert_contains "(7) apply line" "$OUT" "The dotfiles source accepts claude-plugins eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

# (7b) a Codex pin that differs gets the re-pin commands (the generic apply cannot fix it); Claude keeps the apply hint
cp "$H/.codex/config.toml" "$T/codex-config.keep"
printf '[marketplaces.%s]\nsource_type = "git"\nref = "0000000000000000000000000000000000000000"\n' "$OWN" > "$H/.codex/config.toml"
run --quiet
codex_line=$(printf '%s\n' "$OUT" | grep "^The codex marketplace" || true)
assert_contains "(7b) codex: remove" "$codex_line" "codex plugin marketplace remove $OWN"
assert_contains "(7b) codex: add at the accepted sha" "$codex_line" "codex plugin marketplace add mmalyska/claude-plugins --ref $HEAD_SHA"
assert_contains "(7b) codex: per plugin" "$codex_line" "codex plugin add <name>@$OWN"
assert_not_contains "(7b) codex: not the generic apply" "$codex_line" "AI_WORKFLOW_UPGRADE=1 chezmoi apply"
run
assert_contains "(7b) report lists the commands" "$OUT" "codex plugin marketplace add mmalyska/claude-plugins --ref $HEAD_SHA"
cp "$T/codex-config.keep" "$H/.codex/config.toml"
run --quiet; assert_not_contains "(7b) repinned: no codex line" "$OUT" "The codex marketplace"

# (8) a source that is not a repository, or an unreachable remote: silent failure, exit 0, no noise
sed "s#^SOURCE_DIR=.*#SOURCE_DIR=\"$T/not-a-repo\"#" "$T/doctor.sh" > "$T/doctor.norepo.sh"; mkdir -p "$T/not-a-repo"
OUT=$(env -u XDG_STATE_HOME -u CLAUDE_CONFIG_DIR -u CODEX_HOME HOME="$H" PATH="$STUBS:$BASE_PATH" STUB_STATE="$STATE" bash "$T/doctor.norepo.sh" --quiet 2>&1); RC=$?
assert_eq "(8) no repo rc" "$RC" "0"; assert_eq "(8) no repo output" "$OUT" ""
rm -rf "$T/origin.git"; : > "$H/.local/state/ai-workflow/source-fetch"
age_stamp
run --quiet; assert_eq "(8) unreachable remote rc" "$RC" "0"; assert_not_contains "(8) no git noise" "$OUT" "fatal"

# (9) a remote that hangs does not hold the session up: the fetch is cut off after about 4 seconds, with no timeout command
git_in "$T/src" remote set-url origin 'ext::sleep 30'
age_stamp
start=$(date +%s)
OUT=$(env HOME="$H" PATH="$STUBS:$BASE_PATH" STUB_STATE="$STATE" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.ext.allow GIT_CONFIG_VALUE_0=always \
    bash "$T/doctor.sh" --quiet 2>&1); RC=$?
elapsed=$(( $(date +%s) - start ))
assert_eq "(9) hanging remote rc" "$RC" "0"
[ "$elapsed" -le 8 ] || _fail "(9) the fetch was not cut off: took ${elapsed}s"
:
