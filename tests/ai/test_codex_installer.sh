#!/usr/bin/env bash
# shellcheck disable=SC2016  # canary script bodies are intentionally single-quoted
# Codex installer (T08) on stub CLIs. Never touches the real HOME, ~/.codex or the network.
. "$(dirname "$0")/lib.sh"

T=$(new_tmp)
[ -z "$(PATH=$BASE_PATH command -v codex || true)" ] || _fail "a real codex is on $BASE_PATH"
CODEX_TPL=home/.chezmoiscripts/ai/run_onchange_after_110-codex-plugins.sh.tmpl

# render_codex <fixture> <path> -> file with the rendered installer
render_codex() {
    PATH=$2 "$CHEZMOI" --source "$AI_ROOT" --config "$FIXTURES/$1.toml" execute-template < "$AI_ROOT/$CODEX_TPL" > "$T/codex.$1.sh"
    echo "$T/codex.$1.sh"
}
# run_codex <script> [VAR=value...]: stubs on PATH, fresh HOME, log in $LOG; sets RC, OUT, HOMEDIR
run_codex() {
    local script=$1; shift
    HOMEDIR="$T/home.$RANDOM"; LOG="$T/calls.$RANDOM.log"; : > "$LOG"
    OUT=$(env -u XDG_STATE_HOME -u CODEX_HOME HOME="$HOMEDIR" PATH="$STUBS:$BASE_PATH" AI_TEST_LOG="$LOG" "$@" bash "$script" 2>&1)
    RC=$?
}
codex_status() { cat "${1:-$HOMEDIR}/.local/state/ai-workflow/codex.status"; }
# write_codex_state <file> <plugin@marketplace...>: `codex plugin list --json` shaped state
write_codex_state() {
    local f=$1 first=1 id; shift
    { echo '{'; echo '  "installed": ['
      for id in "$@"; do [ $first = 1 ] || echo ","; first=0
          printf '    {\n      "pluginId": "%s",\n      "name": "%s",\n      "installed": true,\n      "enabled": true\n    }' "$id" "${id%@*}"; done
      echo; echo '  ],'; echo '  "available": []'; echo '}'; } > "$f"
}
# write_codex_marketplaces <file> <name>: `codex plugin marketplace list --json` shaped state
write_codex_marketplaces() {
    printf '{\n  "marketplaces": [\n    {\n      "name": "%s",\n      "root": "/x",\n      "marketplaceSource": {\n        "sourceType": "git",\n        "source": "https://github.com/mmalyska/claude-plugins.git"\n      }\n    }\n  ]\n}\n' "$2" > "$1"
}
write_codex_config() { # dir ref
    mkdir -p "$1"
    printf '[marketplaces.%s]\nsource_type = "git"\nsource = "https://github.com/mmalyska/claude-plugins.git"\nref = "%s"\n' "$OWN" "$2" > "$1/config.toml"
}

FULL_STATE="$T/full.json"; MK="$T/mk.json"
ids=(); for p in "${OWN_IDS[@]}"; do ids+=("$p@$OWN"); done
write_codex_state "$FULL_STATE" "${ids[@]}"
write_codex_marketplaces "$MK" "$OWN"
CH_OK="$T/codex-home-ok"; write_codex_config "$CH_OK" "$SHA"
mutating='^codex plugin (add|marketplace add|marketplace upgrade|remove|marketplace remove)'

# (a) no codex on PATH
S=$(render_codex core-linux "$BASE_PATH")
HOMEDIR="$T/home.a"; LOG="$T/a.log"
OUT=$(env -u XDG_STATE_HOME -u CODEX_HOME HOME="$HOMEDIR" PATH="$BASE_PATH" AI_TEST_LOG="$LOG" bash "$S" 2>&1); RC=$?
assert_eq "(a) rc" "$RC" "0"
assert_contains "(a) SKIP" "$OUT" "SKIP codex CLI not found"
[ ! -s "$LOG" ] || _fail "(a) calls were made"
assert_contains "(a) status" "$(codex_status)" "result=skipped"

# (b) core, fresh state
S=$(render_codex core-linux "$STUBS:$BASE_PATH")
run_codex "$S"
assert_eq "(b) rc" "$RC" "0"
assert_calls "(b) marketplace add" "$LOG" "^codex plugin marketplace add mmalyska/claude-plugins --ref $SHA$" 1
assert_calls "(b) add" "$LOG" "^codex plugin add .*@$OWN$" 12
assert_calls "(b) superpowers" "$LOG" "superpowers" 0
assert_calls "(b) official" "$LOG" "$OFFICIAL" 0
assert_calls "(b) upgrade" "$LOG" "marketplace upgrade" 0
assert_contains "(b) done" "$OUT" "DONE codex fails=0"
assert_contains "(b) status" "$(codex_status)" "result=ok"
assert_contains "(b) status sha" "$(codex_status)" "accepted_sha=$SHA"

# (c) rerun with everything installed and pinned: no mutating call, no warning
run_codex "$S" STUB_STATE="$FULL_STATE" STUB_MARKETPLACES="$MK" CODEX_HOME="$CH_OK"
assert_eq "(c) rc" "$RC" "0"
assert_calls "(c) mutating" "$LOG" "$mutating" 0
assert_not_contains "(c) no warning" "$OUT" "WARN"
assert_contains "(c) status" "$(codex_status)" "result=ok"

# pin mismatch: WARN, never replaced, plugins still completed, not a failure
CH_BAD="$T/codex-home-bad"; write_codex_config "$CH_BAD" "deadbeef"
run_codex "$S" STUB_STATE="$FULL_STATE" STUB_MARKETPLACES="$MK" CODEX_HOME="$CH_BAD"
assert_eq "(pin) rc" "$RC" "0"
assert_contains "(pin) WARN" "$OUT" "WARN pin mismatch"
assert_calls "(pin) mutating" "$LOG" "$mutating" 0
assert_calls "(pin) remove" "$LOG" "remove" 0
assert_contains "(pin) status" "$(codex_status)" "result=ok"

# (d) minimal
S_MIN=$(render_codex minimal-linux "$STUBS:$BASE_PATH")
run_codex "$S_MIN"
assert_eq "(d) rc" "$RC" "0"
assert_calls "(d) add" "$LOG" "^codex plugin add" 2
assert_calls "(d) git-workflows" "$LOG" "^codex plugin add git-workflows@$OWN$" 1
assert_calls "(d) development-lifecycle" "$LOG" "^codex plugin add development-lifecycle@$OWN$" 1

# claude-extended: the Claude-only extras are never installed for Codex
S_EXT=$(render_codex extended-linux "$STUBS:$BASE_PATH")
run_codex "$S_EXT"
assert_calls "(ext) add" "$LOG" "^codex plugin add .*@$OWN$" 12
assert_calls "(ext) extras" "$LOG" "superpowers|code-simplifier|context7|claude-md-management|$OFFICIAL" 0

# (e) every plugin add fails: still exit 0, every plugin attempted
run_codex "$S" STUB_FAIL="plugin+add"
assert_eq "(e) rc" "$RC" "0"
assert_calls "(e) attempts" "$LOG" "^codex plugin add" 12
assert_contains "(e) fails" "$OUT" "DONE codex fails=12"
assert_contains "(e) status" "$(codex_status)" "result=partial"
assert_contains "(e) status fails" "$(codex_status)" "fails=12"

# (f) independence of the two installers
SC=$(PATH=$BASE_PATH render_script core-linux "$STUBS:$BASE_PATH")
only() { # only <name> -> dir with a single stub on PATH
    local d="$T/only-$1"; mkdir -p "$d"; ln -sf "$STUBS/$1" "$d/$1"; ln -sf "$STUBS/_stub.sh" "$d/_stub.sh"; echo "$d"
}
for combo in codex claude; do
    other=claude; [ $combo = claude ] && other=codex
    HOMEDIR="$T/home.f.$combo"; LOG="$T/f.$combo.log"; : > "$LOG"
    for s in "$SC" "$S"; do
        OUT=$(env -u XDG_STATE_HOME -u CODEX_HOME -u CLAUDE_CONFIG_DIR HOME="$HOMEDIR" PATH="$(only $combo):$BASE_PATH" AI_TEST_LOG="$LOG" bash "$s" 2>&1) \
            || _fail "(f) installer failed with only $combo present"
    done
    assert_calls "(f) $other not called" "$LOG" "^$other " 0
done
assert_calls "(f) codex only" "$T/f.codex.log" "^codex plugin add" 12
assert_calls "(f) claude only" "$T/f.claude.log" "^claude plugin install" 12
assert_contains "(f) claude skipped" "$(cat "$T/home.f.codex/.local/state/ai-workflow/claude.status")" "result=skipped"
assert_contains "(f) codex skipped" "$(cat "$T/home.f.claude/.local/state/ai-workflow/codex.status")" "result=skipped"
assert_contains "(f) codex complete" "$(codex_status "$T/home.f.codex")" "result=ok"
assert_contains "(f) claude complete" "$(cat "$T/home.f.claude/.local/state/ai-workflow/claude.status")" "result=ok"

# (g) ai_codex=false
S_OFF=$(render_codex core-nocodex-linux "$STUBS:$BASE_PATH")
run_codex "$S_OFF"
assert_eq "(g) rc" "$RC" "0"
assert_contains "(g) SKIP" "$OUT" "SKIP ai_codex=false"
[ ! -s "$LOG" ] || _fail "(g) calls were made"
assert_contains "(g) status" "$(codex_status)" "result=skipped"

# (h) argument scan: no delegation / team / orchestration vocabulary in any call or in the rendered script
for l in "$T"/calls.*.log "$T"/f.*.log; do
    ! grep -qiE 'delegate|team|orchestrat' "$l" || _fail "(h) forbidden argument in $l"
done
! grep -qiE 'delegate|team|orchestrat' "$S" "$S_EXT" "$S_MIN" || _fail "(h) forbidden word in rendered script"

# (i) fingerprint changes when the CLI appears; profile and plugin set are part of it
S_ABSENT=$(render_codex core-linux "$BASE_PATH"); cp "$S_ABSENT" "$T/absent.sh"
S_PRESENT=$(render_codex core-linux "$STUBS:$BASE_PATH")
fp() { sed -n '2p' "$1"; }
assert_contains "(i) absent" "$(fp "$T/absent.sh")" "cli=absent"
assert_contains "(i) present" "$(fp "$S_PRESENT")" "cli=present"
[ "$(fp "$T/absent.sh")" != "$(fp "$S_PRESENT")" ] || _fail "(i) fingerprints equal"
assert_contains "(i) profile" "$(fp "$S_MIN")" "profile=minimal"
assert_not_contains "(i) minimal set" "$(fp "$S_MIN")" "dotnet"

# (j) network failure on the marketplace: exit 0, WARN, no plugin attempts, partial
run_codex "$S" STUB_FAIL="codex:marketplace"
assert_eq "(j) rc" "$RC" "0"
assert_contains "(j) WARN" "$OUT" "WARN"
assert_calls "(j) adds" "$LOG" "^codex plugin add" 0
assert_contains "(j) status" "$(codex_status)" "result=partial"

# static policy on the rendered scripts
for f in "$S" "$S_EXT" "$S_MIN"; do
    ! grep -q '|| true' "$f" || _fail "rendered installer contains '|| true'"
    ! grep -qE 'plugin remove|plugin disable|marketplace remove|marketplace upgrade|uninstall' "$f" || _fail "rendered installer removes or upgrades something"
    while IFS= read -r line; do
        case "$line" in *ai_soft*) ;; *) _fail "mutating codex call outside ai_soft: $line";; esac
    done < <(grep -E 'codex plugin (add|marketplace add)' "$f")
    bash -n "$f" || _fail "bash -n rendered script"
    if command -v shellcheck >/dev/null; then shellcheck -x -s bash "$f" || _fail "shellcheck rendered script"; else echo "  NOT RUN shellcheck (not installed)"; fi
done

# recovery on a real `chezmoi apply` (copy of the tree, system scripts removed, canaries added)
SRC="$T/src"; mkdir -p "$SRC"
rsync -a --exclude .git --exclude .worktrees "$AI_ROOT/" "$SRC/"
rm -rf "$SRC"/home/.chezmoiscripts/{linux,macos,windows,devcontainer}
find "$SRC/home" -maxdepth 1 -name 'run_once_*' -delete
printf '#!/usr/bin/env bash\necho once >> "$AI_TEST_CANARY"\n' > "$SRC/home/.chezmoiscripts/run_once_canary-once.sh"
printf '#!/usr/bin/env bash\necho onchange >> "$AI_TEST_CANARY"\n' > "$SRC/home/.chezmoiscripts/run_onchange_canary-onchange.sh"

recovery() { # recovery <name> <STUB_FAIL value> <expected fails>
    local n=$1 fail=$2 want=$3
    local KHOME="$T/khome.$n" CANARY="$T/canary.$n.log" KLOG="$T/k.$n.log" ST="$T/state.$n.boltdb"
    mkdir -p "$KHOME"; : > "$CANARY"; : > "$KLOG"
    local KCMD=(env -u XDG_STATE_HOME -u CLAUDE_CONFIG_DIR -u CODEX_HOME HOME="$KHOME" PATH="$STUBS:$BASE_PATH" AI_TEST_LOG="$KLOG" AI_TEST_CANARY="$CANARY")
    apply() { "${KCMD[@]}" "$@" "$TIMEOUT" 60 "$CHEZMOI" apply --source "$SRC" --config "$FIXTURES/core-linux.toml" \
        --destination "$KHOME" --persistent-state "$ST" --cache "$T/kcache.$n" </dev/null >"$T/apply.$n.out" 2>&1; }
    local key="$KHOME/.chezmoiscripts/ai/110-codex-plugins.sh" status="$KHOME/.local/state/ai-workflow/codex.status"
    apply STUB_FAIL="$fail" || { cat "$T/apply.$n.out"; _fail "($n 1) apply failed"; }
    assert_contains "($n 1) status" "$(cat "$status")" "result=partial"
    assert_contains "($n 1) fails" "$(cat "$status")" "fails=$want"
    assert_contains "($n 1) claude complete" "$(cat "$KHOME/.local/state/ai-workflow/claude.status")" "result=ok"
    local canary_after_first claude_calls
    canary_after_first=$(wc -l < "$CANARY"); assert_eq "($n 1) canaries ran once each" "$canary_after_first" "2"
    # (2) a plain apply does not retry (documents the trap)
    : > "$KLOG"; apply || _fail "($n 2) apply failed"
    [ ! -s "$KLOG" ] || _fail "($n 2) plain apply re-ran an installer"
    assert_contains "($n 2) still partial" "$(cat "$status")" "result=partial"
    # (3) reset exactly this script's entryState key, apply again
    "${KCMD[@]}" "$CHEZMOI" state dump --persistent-state "$ST" --format json 2>/dev/null | grep -qF "110-codex-plugins.sh" \
        || _fail "($n 3) entryState has no key for the installer"
    "${KCMD[@]}" "$CHEZMOI" state delete --persistent-state "$ST" --bucket=entryState --key="$key" >/dev/null || _fail "($n 3) state delete"
    : > "$KLOG"; apply || { cat "$T/apply.$n.out"; _fail "($n 3) apply failed"; }
    assert_calls "($n 3) adds" "$KLOG" "^codex plugin add" 12
    assert_contains "($n 3) status" "$(cat "$status")" "result=ok"
    claude_calls=$(grep -c '^claude ' "$KLOG" || true); assert_eq "($n 3) claude not repeated" "$claude_calls" "0"
    # (4) canaries did not run again
    assert_eq "($n 4) canaries" "$(wc -l < "$CANARY")" "$canary_after_first"
    # (5) next apply: nothing
    : > "$KLOG"; apply || _fail "($n 5) apply failed"
    [ ! -s "$KLOG" ] || _fail "($n 5) apply re-ran an installer"
}
recovery k "plugin+add" 12            # (i) failing plugin installs
recovery j "codex:marketplace" 1            # (j) network failure; the retry installs everything
