#!/usr/bin/env bash
# T07: the old run_once installer is gone and migrating between profiles never uninstalls anything.
. "$(dirname "$0")/lib.sh"
T=$(new_tmp)

OLD="install-claude""-plugins"
[ ! -e "$AI_ROOT/home/run_once_$OLD.sh" ] || _fail "old run_once script still present"
! grep -rn "$OLD" "$AI_ROOT/home" "$AI_ROOT/tests" "$AI_ROOT/.github" || _fail "references to the old installer remain"
! grep -rnE 'uninstall|plugin (remove|disable)' "$AI_ROOT/home" || _fail "uninstall/remove/disable in home/"

ids=(); for p in "${OWN_IDS[@]}"; do ids+=("$p@$OWN"); done
for p in "${EXTRA_IDS[@]}"; do ids+=("$p@$OFFICIAL"); done
write_state "$T/full16.json" "${ids[@]}"
write_marketplaces "$T/mk.json" "$OWN" "$OFFICIAL"
[ "${#ids[@]}" = 16 ] || _fail "expected 16 installed plugins in the fixture state"

enabled() { # fixture -> sorted enabledPlugins keys
    render "$1" home/dot_claude/settings.json.tmpl | python3 -I -c 'import json,sys; print("\n".join(sorted(json.load(sys.stdin)["enabledPlugins"])))'
}
no_removal_calls() { # logfile
    ! grep -qE 'uninstall|remove|disable' "$1" || _fail "removal call in $1"
}

# (a) legacy host with all 16 plugins: settings identical to golden, installer does nothing
assert_eq "(a) settings" "$(render legacy-linux home/dot_claude/settings.json.tmpl | sorted_json)" "$(sorted_json < "$GOLDEN/legacy.settings.json")"
S=$(render_script legacy-linux "$STUBS:$BASE_PATH")
run_installer "$S" STUB_STATE="$T/full16.json" STUB_MARKETPLACES="$T/mk.json"
assert_eq "(a) rc" "$RC" "0"
assert_calls "(a) mutating" "$LOG" '^claude plugin (install|marketplace add|marketplace update)' 0
assert_calls "(a) any call but queries" "$LOG" '^claude plugin (install|marketplace (add|update|remove)|uninstall|remove|disable)' 0
assert_contains "(a) status" "$(status_of)" "result=ok"
assert_contains "(a) fingerprint" "$(sed -n 2p "$S")" "profile=claude-extended"

# (b) claude-extended -> core -> minimal with all 16 installed
prev=$(enabled extended-linux); [ "$(printf '%s\n' "$prev" | wc -l)" = 16 ] || _fail "(b) extended should enable 16"
for step in core-linux minimal-linux; do
    cur=$(enabled "$step")
    # only removals from enabledPlugins: nothing new appears
    added=$(comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur"))
    assert_eq "(b) $step adds nothing" "$added" ""
    [ "$(printf '%s\n' "$cur" | wc -l)" -lt "$(printf '%s\n' "$prev" | wc -l)" ] || _fail "(b) $step did not shrink the set"
    S=$(render_script "$step" "$STUBS:$BASE_PATH")
    run_installer "$S" STUB_STATE="$T/full16.json" STUB_MARKETPLACES="$T/mk.json"
    assert_eq "(b) $step rc" "$RC" "0"
    assert_calls "(b) $step mutating" "$LOG" '^claude plugin (install|marketplace add|marketplace update)' 0
    no_removal_calls "$LOG"
    prev=$cur
done
assert_eq "(b) minimal set" "$prev" "$(printf '%s\n' "development-lifecycle@$OWN" "git-workflows@$OWN")"
