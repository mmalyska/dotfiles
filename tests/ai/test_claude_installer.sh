#!/usr/bin/env bash
# shellcheck disable=SC2016  # canary script bodies are intentionally single-quoted
# Claude installer (T06) on stub CLIs. Never touches the real HOME, ~/.claude or the network.
. "$(dirname "$0")/lib.sh"

T=$(new_tmp)
[ -z "$(PATH=$BASE_PATH command -v claude || true)" ] || _fail "a real claude is on $BASE_PATH"

FULL_STATE="$T/full.json"; MK_OWN="$T/mk-own.json"; MK_BOTH="$T/mk-both.json"
ids=(); for p in "${OWN_IDS[@]}"; do ids+=("$p@$OWN"); done
write_state "$FULL_STATE" "${ids[@]}"
write_marketplaces "$MK_OWN" "$OWN"
write_marketplaces "$MK_BOTH" "$OWN" "$OFFICIAL"

mutating='^claude plugin (install|marketplace add|marketplace update)'

# (a) no claude on PATH
S=$(render_script core-linux "$BASE_PATH")
HOMEDIR="$T/home.a"; LOG="$T/a.log"
OUT=$(env -u XDG_STATE_HOME HOME="$HOMEDIR" PATH="$BASE_PATH" AI_TEST_LOG="$LOG" bash "$S" 2>&1); RC=$?
assert_eq "(a) rc" "$RC" "0"
assert_contains "(a) SKIP" "$OUT" "SKIP claude CLI not found"
[ ! -s "$LOG" ] || _fail "(a) calls were made"
assert_contains "(a) status" "$(status_of)" "result=skipped"

# (b) core, fresh state
S=$(render_script core-linux "$STUBS:$BASE_PATH")
run_installer "$S"
assert_eq "(b) rc" "$RC" "0"
assert_calls "(b) marketplace add" "$LOG" "^claude plugin marketplace add mmalyska/claude-plugins$" 1
assert_calls "(b) install" "$LOG" "^claude plugin install .*@$OWN$" 12
assert_calls "(b) update" "$LOG" "^claude plugin marketplace update" 0
assert_calls "(b) superpowers" "$LOG" "superpowers" 0
assert_calls "(b) official" "$LOG" "$OFFICIAL" 0
assert_contains "(b) done" "$OUT" "DONE claude fails=0"
assert_contains "(b) status" "$(status_of)" "result=ok"
assert_contains "(b) status sha" "$(status_of)" "accepted_sha=$SHA"

# (c) rerun with everything installed: no mutating call
run_installer "$S" STUB_STATE="$FULL_STATE" STUB_MARKETPLACES="$MK_OWN"
assert_eq "(c) rc" "$RC" "0"
assert_calls "(c) mutating" "$LOG" "$mutating" 0
assert_contains "(c) status" "$(status_of)" "result=ok"

# (d) claude-extended
S_EXT=$(render_script extended-linux "$STUBS:$BASE_PATH")
run_installer "$S_EXT"
assert_eq "(d) rc" "$RC" "0"
assert_calls "(d) official add" "$LOG" "^claude plugin marketplace add anthropics/claude-plugins-official$" 1
assert_calls "(d) own install" "$LOG" "^claude plugin install .*@$OWN$" 12
assert_calls "(d) extras install" "$LOG" "^claude plugin install .*@$OFFICIAL$" 4
assert_calls "(d) superpowers" "$LOG" "^claude plugin install superpowers@$OFFICIAL$" 1
assert_calls "(d) update" "$LOG" "^claude plugin marketplace update" 0
# extended with everything installed -> nothing mutating
ids2=("${ids[@]}"); for p in "${EXTRA_IDS[@]}"; do ids2+=("$p@$OFFICIAL"); done
write_state "$T/full-ext.json" "${ids2[@]}"
run_installer "$S_EXT" STUB_STATE="$T/full-ext.json" STUB_MARKETPLACES="$MK_BOTH"
assert_calls "(d) rerun mutating" "$LOG" "$mutating" 0

# (e) every install fails: still exit 0, every plugin attempted
run_installer "$S" STUB_FAIL="install"
assert_eq "(e) rc" "$RC" "0"
assert_calls "(e) attempts" "$LOG" "^claude plugin install" 12
assert_contains "(e) fails" "$OUT" "DONE claude fails=12"
assert_contains "(e) status" "$(status_of)" "result=partial"
assert_contains "(e) status fails" "$(status_of)" "fails=12"

# (f) minimal
S_MIN=$(render_script minimal-linux "$STUBS:$BASE_PATH")
run_installer "$S_MIN"
assert_eq "(f) rc" "$RC" "0"
assert_calls "(f) marketplace add" "$LOG" "^claude plugin marketplace add mmalyska/claude-plugins$" 1
assert_calls "(f) install" "$LOG" "^claude plugin install" 2
assert_calls "(f) git-workflows" "$LOG" "^claude plugin install git-workflows@$OWN$" 1
assert_calls "(f) development-lifecycle" "$LOG" "^claude plugin install development-lifecycle@$OWN$" 1
assert_calls "(f) extras" "$LOG" "$OFFICIAL" 0

# (g) explicit upgrade: exactly one marketplace update
run_installer "$S" STUB_STATE="$FULL_STATE" STUB_MARKETPLACES="$MK_OWN" AI_WORKFLOW_UPGRADE=1
assert_calls "(g) update" "$LOG" "^claude plugin marketplace update $OWN$" 1
assert_calls "(g) other mutating" "$LOG" "^claude plugin (install|marketplace add)" 0

# (h) marketplace checkout differs from the accepted SHA: WARN, exit 0
CC="$T/claude-config"; MKDIR="$CC/plugins/marketplaces/$OWN"
git init -q "$MKDIR" && git -C "$MKDIR" -c user.email=a@b -c user.name=n commit -q --allow-empty -m x
HEAD_SHA=$(git -C "$MKDIR" rev-parse HEAD)
run_installer "$S" STUB_STATE="$FULL_STATE" STUB_MARKETPLACES="$MK_OWN" CLAUDE_CONFIG_DIR="$CC"
assert_eq "(h) rc" "$RC" "0"
assert_contains "(h) drift" "$OUT" "WARN drift: $OWN is at $HEAD_SHA, accepted $SHA"
assert_calls "(h) mutating" "$LOG" "$mutating" 0

# (i) fingerprint changes when the CLI appears
S_ABSENT=$(render_script core-linux "$BASE_PATH"); cp "$S_ABSENT" "$T/absent.sh"
S_PRESENT=$(render_script core-linux "$STUBS:$BASE_PATH")
fp() { sed -n '2p' "$1"; }
assert_contains "(i) absent" "$(fp "$T/absent.sh")" "cli=absent"
assert_contains "(i) present" "$(fp "$S_PRESENT")" "cli=present"
[ "$(fp "$T/absent.sh")" != "$(fp "$S_PRESENT")" ] || _fail "(i) fingerprints equal"
# the profile and plugin set are part of the fingerprint too
assert_contains "(i) profile" "$(fp "$S_MIN")" "profile=minimal"
assert_not_contains "(i) minimal set" "$(fp "$S_MIN")" "dotnet"

# (j) ai_claude=false
S_OFF=$(render_script core-noclaude-linux "$STUBS:$BASE_PATH")
run_installer "$S_OFF"
assert_eq "(j) rc" "$RC" "0"
assert_contains "(j) SKIP" "$OUT" "SKIP ai_claude=false"
[ ! -s "$LOG" ] || _fail "(j) calls were made"
assert_contains "(j) status" "$(status_of)" "result=skipped"

# marketplace unusable: plugins that depend on it are not attempted
run_installer "$S" STUB_FAIL="marketplace"
assert_eq "(m) rc" "$RC" "0"
assert_calls "(m) installs" "$LOG" "^claude plugin install" 0
assert_contains "(m) status" "$(status_of)" "result=partial"

# static policy on the rendered script
for f in "$S" "$S_EXT" "$S_MIN"; do
    ! grep -q '|| true' "$f" || _fail "rendered installer contains '|| true'"
    ! grep -qE 'uninstall|plugin remove|plugin disable|marketplace remove' "$f" || _fail "rendered installer removes something"
    while IFS= read -r line; do
        case "$line" in *ai_soft*) ;; *) _fail "mutating claude call outside ai_soft: $line";; esac
    done < <(grep -E 'claude plugin (install|marketplace add|marketplace update)' "$f")
    bash -n "$f" || _fail "bash -n rendered script"
    if command -v shellcheck >/dev/null; then shellcheck -x -s bash "$f" || _fail "shellcheck rendered script"; else echo "  NOT RUN shellcheck (not installed)"; fi
done
assert_not_contains "no team/orchestration" "$(cat "$S_EXT")" "delegate"

# (k) recovery on a real `chezmoi apply` (copy of the tree, system scripts removed, canaries added)
SRC="$T/src"; mkdir -p "$SRC"
rsync -a --exclude .git --exclude .worktrees "$AI_ROOT/" "$SRC/"
rm -rf "$SRC"/home/.chezmoiscripts/{linux,macos,windows,devcontainer}
find "$SRC/home" -maxdepth 1 -name 'run_once_*' -delete
printf '#!/usr/bin/env bash\necho once >> "$AI_TEST_CANARY"\n' > "$SRC/home/.chezmoiscripts/run_once_canary-once.sh"
printf '#!/usr/bin/env bash\necho onchange >> "$AI_TEST_CANARY"\n' > "$SRC/home/.chezmoiscripts/run_onchange_canary-onchange.sh"
KHOME="$T/khome"; mkdir -p "$KHOME"; CANARY="$T/canary.log"; : > "$CANARY"; KLOG="$T/k.log"
KCMD=(env -u XDG_STATE_HOME -u CLAUDE_CONFIG_DIR HOME="$KHOME" PATH="$STUBS:$BASE_PATH" AI_TEST_LOG="$KLOG" AI_TEST_CANARY="$CANARY")
apply() { "${KCMD[@]}" "$@" "$TIMEOUT" 60 "$CHEZMOI" apply --source "$SRC" --config "$FIXTURES/core-linux.toml" \
    --destination "$KHOME" --persistent-state "$T/state.boltdb" --cache "$T/kcache" </dev/null >"$T/apply.out" 2>&1; }
KEY="$KHOME/.chezmoiscripts/ai/100-claude-plugins.sh"
: > "$KLOG"
apply STUB_FAIL=install || { cat "$T/apply.out"; _fail "(k1) apply failed"; }
assert_contains "(k1) status" "$(cat "$KHOME/.local/state/ai-workflow/claude.status")" "result=partial"
assert_contains "(k1) fails" "$(cat "$KHOME/.local/state/ai-workflow/claude.status")" "fails=12"
CANARY_AFTER_FIRST=$(wc -l < "$CANARY")
assert_eq "(k1) canaries ran once each" "$CANARY_AFTER_FIRST" "2"
# (2) the failure is not retried by a plain apply (documents the trap)
: > "$KLOG"; apply || _fail "(k2) apply failed"
[ ! -s "$KLOG" ] || _fail "(k2) plain apply re-ran the installer"
# (3) reset exactly this script's entryState key, apply again
"${KCMD[@]}" "$CHEZMOI" state dump --persistent-state "$T/state.boltdb" --format json 2>/dev/null | grep -qF "100-claude-plugins.sh" \
    || _fail "(k3) entryState has no key for the installer"
"${KCMD[@]}" "$CHEZMOI" state delete --persistent-state "$T/state.boltdb" --bucket=entryState --key="$KEY" >/dev/null || _fail "(k3) state delete"
: > "$KLOG"; apply || { cat "$T/apply.out"; _fail "(k3) apply failed"; }
assert_calls "(k3) installs" "$KLOG" "^claude plugin install" 12
assert_contains "(k3) status" "$(cat "$KHOME/.local/state/ai-workflow/claude.status")" "result=ok"
# (4) canaries did not run again
assert_eq "(k4) canaries" "$(wc -l < "$CANARY")" "$CANARY_AFTER_FIRST"
# (5) next apply: nothing
: > "$KLOG"; apply || _fail "(k5) apply failed"
[ ! -s "$KLOG" ] || _fail "(k5) apply re-ran the installer"
