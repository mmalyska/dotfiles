#!/usr/bin/env bash
# shellcheck disable=SC2016  # canary script bodies are intentionally single-quoted
# ai-workflow-doctor (T09) on stub CLIs: read-only report, strict mode, printed (never executed) recovery.
. "$(dirname "$0")/lib.sh"

T=$(new_tmp)
DOCTOR_TPL=home/dot_local/bin/executable_ai-workflow-doctor.tmpl
mkdir -p "$T/bin"; ln -s "$CHEZMOI" "$T/bin/chezmoi"
WITH_CHEZMOI="$STUBS:$T/bin:$BASE_PATH"

render_doctor() { # <fixture> -> path of the rendered doctor
    "$CHEZMOI" --source "$AI_ROOT" --config "$FIXTURES/$1.toml" execute-template < "$AI_ROOT/$DOCTOR_TPL" > "$T/doctor.$1.sh"
    echo "$T/doctor.$1.sh"
}
status_file() { # <home> <harness> <result> <fails>
    mkdir -p "$1/.local/state/ai-workflow"
    printf 'result=%s\nfails=%s\naccepted_sha=%s\ntime=x\n' "$3" "$4" "$SHA" > "$1/.local/state/ai-workflow/$2.status"
}
codex_cfg() { # <home> <ref>
    mkdir -p "$1/.codex"
    printf '[marketplaces.%s]\nsource_type = "git"\nref = "%s"\n' "$OWN" "$2" > "$1/.codex/config.toml"
}
# doctor <script> <home> [VAR=value...] [-- args]: sets RC and OUT, log in $LOG
doctor() {
    local script=$1 home=$2; shift 2
    local envs=() args=()
    while [ $# -gt 0 ] && [ "$1" != -- ]; do envs+=("$1"); shift; done
    [ "${1:-}" = -- ] && shift; args=("$@")
    LOG="$T/doctor.$RANDOM.log"; : > "$LOG"
    OUT=$(env -u XDG_STATE_HOME -u CLAUDE_CONFIG_DIR -u CODEX_HOME HOME="$home" PATH="$STUBS:$BASE_PATH" AI_TEST_LOG="$LOG" "${envs[@]}" bash "$script" "${args[@]}" 2>&1)
    RC=$?
}

ids=(); for p in "${OWN_IDS[@]}"; do ids+=("$p@$OWN"); done
write_state "$T/claude-full.json" "${ids[@]}"
write_codex_state "$T/codex-full.json" "${ids[@]}"
cat "$T/claude-full.json" "$T/codex-full.json" > "$T/both-full.json"
mutating='(plugin (add|install|remove|uninstall|disable|update|upgrade)|marketplace (add|update|upgrade|remove))'

D=$(render_doctor core-linux)
bash -n "$D" || _fail "bash -n rendered doctor"
! grep -q '{{' "$D" || _fail "(a) template delimiters left in the rendered doctor"
if command -v shellcheck >/dev/null; then shellcheck -s bash "$D" || _fail "shellcheck rendered doctor"; else echo "  NOT RUN shellcheck (not installed)"; fi
# the doctor never mutates: its only CLI calls are `plugin list`/--version, and it never runs chezmoi itself
while IFS= read -r line; do
    case "$line" in *"plugin list --json"*) ;; *) _fail "(a) unexpected CLI call in doctor: $line";; esac
done < <(grep -E '(claude|codex) (plugin|marketplace)' "$D" | grep -vE '^\s*#')
! grep -E '^[^#]*(\$\(|`|^\s*)chezmoi ' "$D" | grep -vE '^\s+chezmoi ' >/dev/null || _fail "(a) doctor runs chezmoi"

# (a) managed name and mode, and the applied file
mgd=$("$CHEZMOI" --source "$AI_ROOT" --config "$FIXTURES/core-linux.toml" --destination "$T/dest" managed --include files)
assert_contains "(a) managed" "$mgd" ".local/bin/ai-workflow-doctor"
assert_not_contains "(a) tmpl suffix" "$mgd" "ai-workflow-doctor.tmpl"
assert_not_contains "(a) tmp suffix" "$mgd" "ai-workflow-doctor.tmp"
mkdir -p "$T/dest"
"$CHEZMOI" apply --source "$AI_ROOT" --config "$FIXTURES/core-linux.toml" --destination "$T/dest" --persistent-state "$T/a.boltdb" \
    --cache "$T/a-cache" --include dirs,files </dev/null >/dev/null 2>&1 || _fail "(a) apply of the doctor"
[ -x "$T/dest/.local/bin/ai-workflow-doctor" ] || _fail "(a) doctor is not executable"
! grep -q '{{' "$T/dest/.local/bin/ai-workflow-doctor" || _fail "(a) applied doctor contains {{"

# (b) everything installed and pinned: all OK, strict exit 0. HEAD of the marketplace checkout is made the accepted SHA by
# patching the rendered constant (a real commit cannot be forged to have the accepted SHA).
HB="$T/home.b"; MKDIR="$HB/.claude/plugins/marketplaces/$OWN"
git init -q "$MKDIR" && git -C "$MKDIR" -c user.email=a@b -c user.name=n commit -q --allow-empty -m x
HEAD_SHA=$(git -C "$MKDIR" rev-parse HEAD)
sed "s/^ACCEPTED_SHA=.*/ACCEPTED_SHA=\"$HEAD_SHA\"/" "$D" > "$T/doctor.b.sh"
codex_cfg "$HB" "$HEAD_SHA"; status_file "$HB" claude ok 0; status_file "$HB" codex ok 0
doctor "$T/doctor.b.sh" "$HB" STUB_STATE="$T/both-full.json" -- --strict
assert_eq "(b) rc" "$RC" "0"
assert_contains "(b) claude marketplace" "$OUT" "marketplace $OWN: OK"
assert_contains "(b) claude plugins" "$OUT" "plugins: 12/12 OK"
assert_not_contains "(b) no missing" "$OUT" "MISSING"
assert_contains "(b) result" "$OUT" "result: OK"
assert_calls "(e) read-only calls" "$LOG" "$mutating" 0

# (c) HEAD differs from the accepted SHA: DRIFT, exit 0, strict exit 1
doctor "$D" "$HB" STUB_STATE="$T/both-full.json"
assert_eq "(c) rc" "$RC" "0"
assert_contains "(c) drift" "$OUT" "marketplace $OWN: DRIFT"
doctor "$D" "$HB" STUB_STATE="$T/both-full.json" -- --strict
assert_eq "(c) strict rc" "$RC" "1"
assert_calls "(c) read-only calls" "$LOG" "$mutating" 0

# MISSING plugin + EXTRA + superpowers warning
write_state "$T/claude-miss.json" "${ids[@]:1}" "superpowers@$OFFICIAL" "other@$OWN"
doctor "$D" "$HB" STUB_STATE="$T/claude-miss.json" -- --strict
assert_eq "(miss) strict rc" "$RC" "1"
assert_contains "(miss) missing" "$OUT" "MISSING: personal-essentials"
assert_contains "(miss) extra" "$OUT" "other@$OWN"
assert_contains "(miss) superpowers" "$OUT" "WARN superpowers is enabled in claude but profile core does not include it"

# (d) neither CLI: ABSENT, exit 0 (also strict)
HD="$T/home.d"; mkdir -p "$HD"
OUT=$(env -u XDG_STATE_HOME HOME="$HD" PATH="$BASE_PATH" bash "$D" --strict 2>&1); RC=$?
assert_eq "(d) rc" "$RC" "0"
assert_contains "(d) claude" "$OUT" "[claude] enabled"
assert_contains "(d) absent" "$OUT" "CLI: ABSENT"
# (h) skipped installers (no CLI / ai_*=false) are never an error in strict mode
HS="$T/home.h"; status_file "$HS" claude skipped 0; status_file "$HS" codex skipped 0
OUT=$(env -u XDG_STATE_HOME HOME="$HS" PATH="$BASE_PATH" bash "$D" --strict 2>&1); RC=$?
assert_eq "(h) strict rc" "$RC" "0"
assert_contains "(h) status" "$OUT" "installer: skipped"
DOFF=$(render_doctor core-nocodex-linux)
doctor "$DOFF" "$HS" STUB_STATE="$T/claude-full.json" -- --strict
assert_contains "(h) disabled" "$OUT" "[codex] disabled"
assert_eq "(h) disabled strict rc" "$RC" "0"

# (f)+(g) the full recovery sequence on a real `chezmoi apply` with the default config/state under HOME=$KHOME
SRC="$T/src"; mkdir -p "$SRC"
rsync -a --exclude .git --exclude .worktrees "$AI_ROOT/" "$SRC/"
rm -rf "$SRC"/home/.chezmoiscripts/{linux,macos,windows,devcontainer}
find "$SRC/home" -maxdepth 1 -name 'run_once_*' -delete
printf '#!/usr/bin/env bash\necho once >> "$AI_TEST_CANARY"\n' > "$SRC/home/.chezmoiscripts/run_once_canary-once.sh"
printf '#!/usr/bin/env bash\necho onchange >> "$AI_TEST_CANARY"\n' > "$SRC/home/.chezmoiscripts/run_onchange_canary-onchange.sh"
KHOME="$T/khome"; mkdir -p "$KHOME/.config/chezmoi"
{ printf 'sourceDir = "%s"\n' "$SRC"; cat "$FIXTURES/core-linux.toml"; } > "$KHOME/.config/chezmoi/chezmoi.toml"
CANARY="$T/canary.log"; : > "$CANARY"; KLOG="$T/k.log"; : > "$KLOG"
codex_cfg "$KHOME" "$SHA"
# XDG_* pinned under $KHOME so chezmoi finds the config/state below $KHOME whatever the runner exports
kenv() { env -u XDG_STATE_HOME -u CLAUDE_CONFIG_DIR -u CODEX_HOME HOME="$KHOME" XDG_CONFIG_HOME="$KHOME/.config" XDG_DATA_HOME="$KHOME/.local/share" XDG_CACHE_HOME="$KHOME/.cache" PATH="$WITH_CHEZMOI" AI_TEST_LOG="$KLOG" AI_TEST_CANARY="$CANARY" "$@"; }
FIX="$T/codex-claude-fixed.json"; cp "$T/both-full.json" "$FIX"
kenv STUB_FAIL="plugin+add" STUB_STATE="$T/claude-full.json" "$TIMEOUT" 60 "$CHEZMOI" apply </dev/null >"$T/apply1.out" 2>&1 || { cat "$T/apply1.out"; _fail "(f) first apply"; }
CANARY_N=$(wc -l < "$CANARY"); assert_eq "(f) canaries once" "$CANARY_N" "2"
DOC="$KHOME/.local/bin/ai-workflow-doctor"
[ -x "$DOC" ] || _fail "(f) doctor not installed by apply"
assert_contains "(f) partial" "$(cat "$KHOME/.local/state/ai-workflow/codex.status")" "result=partial"

before=$(kenv "$CHEZMOI" state dump --format json 2>/dev/null)
OUT=$(kenv STUB_STATE="$T/claude-full.json" bash "$DOC" --strict 2>&1); RC=$?
after=$(kenv "$CHEZMOI" state dump --format json 2>/dev/null)
assert_eq "(f) strict fails on partial" "$RC" "1"
assert_eq "(g) entryState unchanged by the doctor" "$after" "$before"
cmd_delete=$(printf '%s\n' "$OUT" | sed -n 's/^    \(chezmoi state delete .*\)$/\1/p')
cmd_apply=$(printf '%s\n' "$OUT" | sed -n 's/^    \(chezmoi apply\)$/\1/p')
[ -n "$cmd_delete" ] && [ -n "$cmd_apply" ] || { printf '%s\n' "$OUT"; _fail "(f) doctor printed no recovery commands"; }
# (g) exactly one key, the right one, and no forbidden verbs
assert_eq "(g) one delete command" "$(printf '%s\n' "$cmd_delete" | wc -l | tr -d ' ')" "1"
assert_eq "(g) one key" "$(printf '%s\n' "$cmd_delete" | grep -o -- '--key=' | wc -l | tr -d ' ')" "1"
assert_contains "(g) key" "$cmd_delete" "--bucket=entryState --key=\"$KHOME/.chezmoiscripts/ai/110-codex-plugins.sh\""
for bad in delete-bucket "state reset" scriptState; do assert_not_contains "(g) printed $bad" "$cmd_delete$cmd_apply" "$bad"; done
assert_not_contains "(g) other harness" "$cmd_delete" "100-claude"
# the printed commands, verbatim
: > "$KLOG"
kenv bash -c "$cmd_delete" >/dev/null || _fail "(f) printed delete command failed"
kenv STUB_STATE="$FIX" bash -c "$cmd_apply" </dev/null >"$T/apply2.out" 2>&1 || { cat "$T/apply2.out"; _fail "(f) printed apply command failed"; }
# the stubs do not persist installs: STUB_STATE already shows the repaired world, so the re-run finds nothing to add
assert_calls "(f) codex installer re-ran" "$KLOG" "^codex plugin list" 1
assert_calls "(f) no plugin left to add" "$KLOG" "^codex plugin add" 0
assert_calls "(f) claude not repeated" "$KLOG" "^claude " 0
assert_eq "(f) canaries" "$(wc -l < "$CANARY")" "$CANARY_N"
assert_contains "(f) ok" "$(cat "$KHOME/.local/state/ai-workflow/codex.status")" "result=ok"
OUT=$(kenv STUB_STATE="$FIX" bash "$DOC" --strict 2>&1); RC=$?
assert_eq "(f) strict ok" "$RC" "0"
