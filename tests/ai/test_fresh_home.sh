#!/usr/bin/env bash
# shellcheck disable=SC2016  # canary script bodies are intentionally single-quoted
# T13 layer A: fresh-environment end-to-end on stub CLIs. Deterministic, offline; every scenario is PASS or FAIL (never NOT RUN).
# Each cell is a real `chezmoi init --apply` into a throw-away HOME on a copy of the tree WITHOUT the system scripts
# (linux/macos/windows/devcontainer, run_once_*), so no sudo/pacman/brew can run. Native CLIs: tests/ai/e2e-native.sh.
. "$(dirname "$0")/lib.sh"

T=$(new_tmp)
REAL="${AI_REAL_HOME:-$HOME}"
real_sums() { (cd "$REAL" && sha256sum .claude/settings.json .codex/config.toml 2>/dev/null; true); }
real_before=$(real_sums); repo_before=$(git -C "$AI_ROOT" status --porcelain 2>/dev/null | sha256sum)

SRC="$T/src"; mkdir -p "$SRC"
rsync -a --exclude .git --exclude .worktrees "$AI_ROOT/" "$SRC/"
rm -rf "$SRC"/home/.chezmoiscripts/{linux,macos,windows,devcontainer}
find "$SRC/home" -maxdepth 1 -name 'run_once_*' -delete
printf '#!/usr/bin/env bash\necho once >> "$AI_TEST_CANARY"\n' > "$SRC/home/.chezmoiscripts/run_once_canary-once.sh"
printf '#!/usr/bin/env bash\necho onchange >> "$AI_TEST_CANARY"\n' > "$SRC/home/.chezmoiscripts/run_onchange_canary-onchange.sh"
[ -z "$(find "$SRC/home" -path '*/.chezmoiscripts/*' -name '*.sh*' ! -path '*/.chezmoiscripts/ai/*' ! -name '*canary*')" ] || _fail "system scripts left in the copied tree"

mutating='(plugin (add|install|remove|uninstall|disable|update|upgrade)|marketplace (add|update|upgrade|remove))'
own_ids=(); for p in "${OWN_IDS[@]}"; do own_ids+=("$p@$OWN"); done
ext_ids=("${own_ids[@]}"); for p in "${EXTRA_IDS[@]}"; do ext_ids+=("$p@$OFFICIAL"); done
write_state "$T/claude-own.json" "${own_ids[@]}"; write_state "$T/claude-ext.json" "${ext_ids[@]}"
write_codex_state "$T/codex-own.json" "${own_ids[@]}"
cat "$T/claude-own.json" "$T/codex-own.json" > "$T/full-own.json"
cat "$T/claude-ext.json" "$T/codex-own.json" > "$T/full-ext.json"
write_marketplaces "$T/mk-both.json" "$OWN" "$OFFICIAL"
CELLS=0

# ---- cell helpers ----
mk_cell() { # <name> <both|claude|codex|none> -> cell dir (own HOME, own PATH dir with the stub CLIs that exist in this cell)
    local c="$T/cell.$1"
    mkdir -p "$c/home/.local/share" "$c/bin"
    ln -s "$SRC" "$c/home/.local/share/chezmoi"   # default source dir, so the doctor's printed `chezmoi apply` works verbatim
    ln -s "$CHEZMOI" "$c/bin/chezmoi"
    case "$2" in both|claude) printf '#!/bin/sh\nexec "%s/claude" "$@"\n' "$STUBS" > "$c/bin/claude";; esac
    case "$2" in both|codex) printf '#!/bin/sh\nexec "%s/codex" "$@"\n' "$STUBS" > "$c/bin/codex";; esac
    chmod +x "$c/bin"/* 2>/dev/null
    : > "$c/calls.log"; : > "$c/canary.log"
    echo "$c"
}
cx() { # <cell> <cmd...>: run inside the cell (private HOME/XDG, stub PATH, call log, canaries)
    local c=$1; shift
    env -u XDG_STATE_HOME -u CLAUDE_CONFIG_DIR -u CODEX_HOME HOME="$c/home" XDG_CONFIG_HOME="$c/home/.config" \
        XDG_DATA_HOME="$c/home/.local/share" XDG_CACHE_HOME="$c/home/.cache" PATH="$c/bin:$BASE_PATH" \
        AI_TEST_LOG="$c/calls.log" AI_TEST_CANARY="$c/canary.log" "$@"
}
cz() { cx "$1" "$TIMEOUT" 60 chezmoi --source "$SRC" "${@:2}" </dev/null; } # chezmoi in a cell
render_tpl() { cx "$1" chezmoi --source "$SRC" execute-template < "$2"; }   # <cell> <template>: stdout
init_apply() { # <cell> <profile> [more init flags]; fails the test on a non-zero exit
    local c=$1 p=$2; shift 2
    cz "$c" init --apply --promptDefaults --promptChoice "$PROMPT_PROFILE=$p" "${PRE_FLAGS[@]}" "$@" >"$c/init.out" 2>&1 \
        || { cat "$c/init.out"; _fail "init --apply failed in $c"; }
}
reapply() { cz "$1" apply >"$1/apply.out" 2>&1 || { cat "$1/apply.out"; _fail "apply failed in $1"; }; }
calls() { grep -cE "$2" "$1/calls.log" 2>/dev/null || true; }
status() { sed -n "s/^$2=//p" "$1/home/.local/state/ai-workflow/$3.status" 2>/dev/null; } # <cell> <field> <harness>
settings_plugins() { # <cell> -> "<total> <own> <official>"
    python3 -I -c '
import json, sys
e = json.load(open(sys.argv[1]))["enabledPlugins"]
print(len(e), sum(k.endswith("@mmalyska-claude-plugins") for k in e), sum(k.endswith("@claude-plugins-official") for k in e))' "$1/home/.claude/settings.json"
}
no_strings() { # <cell>: no workflow vocabulary or secrets in what dotfiles wrote into ~/.claude, no delegation in any CLI call
    local c=$1
    ! grep -rEi 'STANDARD|SOLO|topology|"profile"|ghp_|sk-[a-z0-9]|api[_-]?key|password' "$c/home/.claude" >/dev/null 2>&1 || _fail "workflow vocabulary or secret in $c/home/.claude"
    ! grep -Ei 'delegate|team|orchestrat' "$c/calls.log" >/dev/null 2>&1 || _fail "delegation-like CLI argument in $c"
}
assert_clean_diff() { # <cell>
    local d
    d=$(cz "$1" diff 2>&1) || _fail "chezmoi diff failed in $1"
    [ -z "$d" ] || { printf '%s\n' "$d" | head -20; _fail "chezmoi diff is not empty in $1"; }
}

# ---- the matrix: {minimal, core, claude-extended} x {both CLIs, only claude, only codex, none} ----
run_cell() { # <profile> <cli-set>
    local p=$1 s=$2 c n_own n_ext want_claude want_codex n_total
    c=$(mk_cell "$p.$s" "$s")
    case "$p" in minimal) n_own=2; n_ext=0;; core) n_own=12; n_ext=0;; *) n_own=12; n_ext=4;; esac
    n_total=$((n_own + n_ext))
    case "$s" in both|claude) want_claude=1;; *) want_claude=0;; esac
    case "$s" in both|codex) want_codex=1;; *) want_codex=0;; esac

    init_apply "$c" "$p"                                              # first apply: exit 0
    assert_eq "[$p/$s] settings plugins" "$(settings_plugins "$c")" "$n_total $n_own $n_ext"
    [ "$p" != claude-extended ] || grep -q 'superpowers@claude-plugins-official' "$c/home/.claude/settings.json" || _fail "[$p/$s] superpowers missing"
    [ "$p" = claude-extended ] || ! grep -q 'superpowers' "$c/home/.claude/settings.json" || _fail "[$p/$s] superpowers present"
    assert_not_contains "[$p/$s] agent teams" "$(cat "$c/home/.claude/settings.json")" 'AGENT_TEAMS'
    [ -x "$c/home/.local/bin/ai-workflow-doctor" ] || _fail "[$p/$s] doctor not installed"
    assert_eq "[$p/$s] canaries after first apply" "$(wc -l < "$c/canary.log" | tr -d ' ')" "2"

    if [ $want_claude = 1 ]; then
        assert_calls "[$p/$s] claude installs" "$c/calls.log" "^claude plugin install" "$n_total"
        assert_calls "[$p/$s] claude own installs" "$c/calls.log" "^claude plugin install .*@$OWN$" "$n_own"
        assert_calls "[$p/$s] claude marketplace add" "$c/calls.log" "^claude plugin marketplace add" "$((1 + (n_ext > 0)))"
        assert_calls "[$p/$s] claude update" "$c/calls.log" "^claude plugin marketplace update" 0
        assert_calls "[$p/$s] superpowers" "$c/calls.log" "^claude plugin install superpowers@" "$((n_ext > 0))"
        assert_eq "[$p/$s] claude status" "$(status "$c" result claude)" "ok"
    else
        assert_calls "[$p/$s] claude not called" "$c/calls.log" "^claude " 0
        assert_eq "[$p/$s] claude status" "$(status "$c" result claude)" "skipped"
    fi
    if [ $want_codex = 1 ]; then
        assert_calls "[$p/$s] codex marketplace" "$c/calls.log" "^codex plugin marketplace add mmalyska/claude-plugins --ref $SHA$" 1
        assert_calls "[$p/$s] codex plugin add" "$c/calls.log" "^codex plugin add .*@$OWN$" "$n_own"
        assert_calls "[$p/$s] codex gets no extras" "$c/calls.log" "^codex .*(superpowers|$OFFICIAL)" 0
        assert_eq "[$p/$s] codex status" "$(status "$c" result codex)" "ok"
    else
        assert_calls "[$p/$s] codex not called" "$c/calls.log" "^codex " 0
        assert_eq "[$p/$s] codex status" "$(status "$c" result codex)" "skipped"
    fi
    no_strings "$c"

    # second apply: exit 0, empty diff, nothing re-run, nothing mutating
    : > "$c/calls.log"
    reapply "$c"
    assert_clean_diff "$c"
    assert_calls "[$p/$s] second apply mutating" "$c/calls.log" "$mutating" 0
    [ ! -s "$c/calls.log" ] || _fail "[$p/$s] second apply called a CLI: $(head -3 "$c/calls.log")"
    assert_eq "[$p/$s] canaries after second apply" "$(wc -l < "$c/canary.log" | tr -d ' ')" "2"

    # installer level idempotence: with everything installed the installers themselves make no mutating call
    local state=$T/full-own.json
    [ "$p" != claude-extended ] || state=$T/full-ext.json
    local tpl
    for tpl in 100-claude-plugins 110-codex-plugins; do
        render_tpl "$c" "$SRC/home/.chezmoiscripts/ai/run_onchange_after_$tpl.sh.tmpl" > "$c/$tpl.sh" || _fail "render $tpl"
        grep -q 'ai_summary' "$c/$tpl.sh" || _fail "[$p/$s] rendered $tpl is empty"
        : > "$c/calls.log"
        cx "$c" env STUB_STATE="$state" STUB_MARKETPLACES="$T/mk-both.json" bash "$c/$tpl.sh" >/dev/null 2>&1 || _fail "[$p/$s] $tpl rerun failed"
        assert_calls "[$p/$s] $tpl rerun mutating" "$c/calls.log" "$mutating" 0
    done

    if [ "$s" = none ]; then   # no CLI at all: doctor strict is fine, skipped is not an error
        OUT=$(cx "$c" bash "$c/home/.local/bin/ai-workflow-doctor" --strict 2>&1); RC=$?
        assert_eq "[$p/none] doctor strict rc" "$RC" "0"
        assert_contains "[$p/none] doctor absent" "$OUT" "CLI: ABSENT"
    fi
    CELLS=$((CELLS + 1))
}
for p in minimal core claude-extended; do for s in both claude codex none; do run_cell "$p" "$s"; done; done
echo "  matrix: $CELLS cells (3 profiles x 4 CLI sets)"

# ---- ai_claude=false / ai_codex=false / both false: SKIP, nothing mutating for the disabled harness, the other one untouched ----
flag_cell() { # <name> <claude:true|false> <codex:true|false>
    local c; c=$(mk_cell "$1" both)
    init_apply "$c" core --promptBool "$PROMPT_CLAUDE=$2" --promptBool "$PROMPT_CODEX=$3"
    if [ "$2" = false ]; then
        assert_calls "[$1] claude not called" "$c/calls.log" "^claude " 0
        assert_eq "[$1] claude status" "$(status "$c" result claude)" "skipped"
    else
        assert_calls "[$1] claude installs" "$c/calls.log" "^claude plugin install" 12
        assert_eq "[$1] claude status" "$(status "$c" result claude)" "ok"
    fi
    if [ "$3" = false ]; then
        assert_calls "[$1] codex not called" "$c/calls.log" "^codex " 0
        assert_eq "[$1] codex status" "$(status "$c" result codex)" "skipped"
    else
        assert_calls "[$1] codex adds" "$c/calls.log" "^codex plugin add" 12
        assert_eq "[$1] codex status" "$(status "$c" result codex)" "ok"
    fi
    assert_contains "[$1] SKIP logged" "$(cat "$c/init.out")" "$([ "$2" = false ] && echo 'SKIP ai_claude=false' || echo 'SKIP ai_codex=false')"
    : > "$c/calls.log"; reapply "$c"; assert_clean_diff "$c"
    assert_calls "[$1] second apply mutating" "$c/calls.log" "$mutating" 0
    OUT=$(cx "$c" bash "$c/home/.local/bin/ai-workflow-doctor" 2>&1)
    assert_contains "[$1] doctor flags" "$OUT" "[claude] $([ "$2" = true ] && echo enabled || echo disabled)"
    CELLS=$((CELLS + 1))
}
flag_cell no-claude false true
flag_cell no-codex true false
flag_cell no-both false false
echo "  flags: ai_claude/ai_codex = false cells ok"

# ---- helpers for recovery ----
printed_cmds() { # <doctor output> <script basename> -> sets CMD_DEL, CMD_APPLY (printed, never executed by the doctor)
    CMD_DEL=$(printf '%s\n' "$1" | sed -n "s/^    \(chezmoi state delete .*$2\"\)\$/\1/p")
    CMD_APPLY=$(printf '%s\n' "$1" | sed -n 's/^    \(chezmoi apply\)$/\1/p' | head -n 1)
    [ -n "$CMD_DEL" ] && [ -n "$CMD_APPLY" ] || { printf '%s\n' "$1"; _fail "doctor printed no recovery commands for $2"; }
    assert_eq "one delete command for $2" "$(printf '%s\n' "$CMD_DEL" | wc -l | tr -d ' ')" "1"
    assert_eq "one key for $2" "$(printf '%s\n' "$CMD_DEL" | grep -o -- '--key=' | wc -l | tr -d ' ')" "1"
    for bad in delete-bucket "state reset" scriptState; do assert_not_contains "printed $bad" "$CMD_DEL$CMD_APPLY" "$bad"; done
}
entry_state() { cx "$1" "$CHEZMOI" state dump --format json 2>/dev/null; }
doctor_strict() { OUT=$(cx "$1" env "${@:2}" bash "$1/home/.local/bin/ai-workflow-doctor" --strict 2>&1); RC=$?; }

# ---- no network (stub): WARN, exit 0, partial, no plugin attempted, doctor strict 1, then one-key recovery per harness ----
c=$(mk_cell net both)
cx "$c" env STUB_FAIL="marketplace" "$TIMEOUT" 60 "$CHEZMOI" --source "$SRC" init --apply --promptDefaults --promptChoice "$PROMPT_PROFILE=core" "${PRE_FLAGS[@]}" </dev/null >"$c/init.out" 2>&1 \
    || { cat "$c/init.out"; _fail "(net) init --apply must exit 0 without network"; }
assert_contains "(net) WARN" "$(cat "$c/init.out")" "WARN"
assert_eq "(net) claude status" "$(status "$c" result claude)" "partial"
assert_eq "(net) codex status" "$(status "$c" result codex)" "partial"
assert_calls "(net) claude installs not attempted" "$c/calls.log" "^claude plugin install" 0
assert_calls "(net) codex adds not attempted" "$c/calls.log" "^codex plugin add" 0
CANARY_N=$(wc -l < "$c/canary.log" | tr -d ' ')
doctor_strict "$c"
assert_eq "(net) doctor strict rc" "$RC" "1"
assert_contains "(net) doctor partial" "$OUT" "installer: partial"
before=$(entry_state "$c")
printed_cmds "$OUT" 100-claude-plugins.sh; CLAUDE_DEL=$CMD_DEL; CLAUDE_APPLY=$CMD_APPLY
printed_cmds "$OUT" 110-codex-plugins.sh; CODEX_DEL=$CMD_DEL
assert_eq "(net) doctor did not reset state" "$(entry_state "$c")" "$before"
# the network is back; reset the Claude key only
: > "$c/calls.log"
cx "$c" bash -c "$CLAUDE_DEL" >/dev/null || _fail "(net) printed claude delete failed"
cx "$c" env STUB_STATE="$T/full-own.json" STUB_MARKETPLACES="$T/mk-both.json" bash -c "$CLAUDE_APPLY" </dev/null >"$c/apply.out" 2>&1 || { cat "$c/apply.out"; _fail "(net) printed apply failed"; }
assert_eq "(net) claude recovered" "$(status "$c" result claude)" "ok"
assert_eq "(net) codex still partial" "$(status "$c" result codex)" "partial"
assert_calls "(net) codex not repeated" "$c/calls.log" "^codex " 0
# then the Codex key only
cx "$c" bash -c "$CODEX_DEL" >/dev/null || _fail "(net) printed codex delete failed"
cx "$c" env STUB_STATE="$T/full-own.json" STUB_MARKETPLACES="$T/mk-both.json" bash -c "$CLAUDE_APPLY" </dev/null >"$c/apply.out" 2>&1 || { cat "$c/apply.out"; _fail "(net) second printed apply failed"; }
assert_eq "(net) codex recovered" "$(status "$c" result codex)" "ok"
assert_eq "(net) canaries never re-ran" "$(wc -l < "$c/canary.log" | tr -d ' ')" "$CANARY_N"
doctor_strict "$c" STUB_STATE="$T/full-own.json"
assert_eq "(net) doctor strict after recovery" "$RC" "0"
CELLS=$((CELLS + 1)); echo "  offline: partial -> doctor 1 -> one-key reset per harness -> ok"

# ---- recovery after failed installs (T06(k) / T09(f) shape, both harnesses) ----
c=$(mk_cell recovery both)
cx "$c" env STUB_FAIL="claude:install codex:plugin+add" "$TIMEOUT" 60 "$CHEZMOI" --source "$SRC" init --apply --promptDefaults --promptChoice "$PROMPT_PROFILE=core" "${PRE_FLAGS[@]}" </dev/null >"$c/init.out" 2>&1 \
    || { cat "$c/init.out"; _fail "(rec) first apply must exit 0"; }
assert_eq "(rec) claude partial" "$(status "$c" result claude)" "partial"
assert_eq "(rec) claude fails" "$(status "$c" fails claude)" "12"
assert_eq "(rec) codex partial" "$(status "$c" result codex)" "partial"
CANARY_N=$(wc -l < "$c/canary.log" | tr -d ' ')
: > "$c/calls.log"; reapply "$c"                                         # a plain apply does not retry (documents the trap)
[ ! -s "$c/calls.log" ] || _fail "(rec) plain apply re-ran an installer"
doctor_strict "$c"
assert_eq "(rec) doctor strict rc" "$RC" "1"
printed_cmds "$OUT" 100-claude-plugins.sh
assert_contains "(rec) key" "$CMD_DEL" "--bucket=entryState --key=\"$c/home/.chezmoiscripts/ai/100-claude-plugins.sh\""
: > "$c/calls.log"
cx "$c" bash -c "$CMD_DEL" >/dev/null || _fail "(rec) delete failed"
cx "$c" env bash -c "$CMD_APPLY" </dev/null >"$c/apply.out" 2>&1 || { cat "$c/apply.out"; _fail "(rec) apply after reset failed"; }
assert_calls "(rec) claude re-ran" "$c/calls.log" "^claude plugin install" 12
assert_calls "(rec) codex not re-ran" "$c/calls.log" "^codex " 0
assert_eq "(rec) claude ok" "$(status "$c" result claude)" "ok"
assert_eq "(rec) canaries after reset" "$(wc -l < "$c/canary.log" | tr -d ' ')" "$CANARY_N"
: > "$c/calls.log"; reapply "$c"
[ ! -s "$c/calls.log" ] || _fail "(rec) apply after recovery re-ran something"
printed_cmds "$(cx "$c" bash "$c/home/.local/bin/ai-workflow-doctor" --strict 2>&1)" 110-codex-plugins.sh
cx "$c" bash -c "$CMD_DEL" >/dev/null || _fail "(rec) codex delete failed"
cx "$c" bash -c "$CMD_APPLY" </dev/null >"$c/apply.out" 2>&1 || { cat "$c/apply.out"; _fail "(rec) codex apply failed"; }
assert_eq "(rec) codex ok" "$(status "$c" result codex)" "ok"
assert_eq "(rec) canaries at the end" "$(wc -l < "$c/canary.log" | tr -d ' ')" "$CANARY_N"
doctor_strict "$c" STUB_STATE="$T/full-own.json"
assert_eq "(rec) doctor strict after recovery" "$RC" "0"
CELLS=$((CELLS + 1)); echo "  recovery: failure -> doctor --strict -> printed one-key reset -> apply -> doctor --strict ok"

# ---- legacy host: config without ai_* -> apply -> init -> apply ----
c=$(mk_cell legacy both)
mkdir -p "$c/home/.config/chezmoi"; cp "$FIXTURES/legacy-linux.toml" "$c/home/.config/chezmoi/chezmoi.toml"
reapply "$c"
assert_eq "(legacy) settings == golden" "$(sorted_json < "$c/home/.claude/settings.json")" "$(sorted_json < "$GOLDEN/legacy.settings.json")"
assert_calls "(legacy) fallback installs the full previous set" "$c/calls.log" "^claude plugin install" 16
# no AI flags and no TTY: the AI keys must not prompt. PRE_FLAGS answers the older prompts (the template reads data key "isWork" but
# writes is_work, so that prompt always re-asks; pre-existing and out of scope here).
cz "$c" init "${PRE_FLAGS[@]}" >"$c/init.out" 2>&1 || { cat "$c/init.out"; _fail "(legacy) init without AI flags and without TTY must exit 0"; }
assert_eq "(legacy) explicit profile" "$(toml_get "$c/home/.config/chezmoi/chezmoi.toml" ai_profile)" "claude-extended"
assert_eq "(legacy) explicit teams" "$(toml_get "$c/home/.config/chezmoi/chezmoi.toml" ai_agent_teams)" "true"
: > "$c/calls.log"; reapply "$c"
assert_clean_diff "$c"
assert_eq "(legacy) settings still == golden" "$(sorted_json < "$c/home/.claude/settings.json")" "$(sorted_json < "$GOLDEN/legacy.settings.json")"
[ ! -s "$c/calls.log" ] || _fail "(legacy) apply after init re-ran an installer"
CELLS=$((CELLS + 1)); echo "  legacy: apply -> init -> apply, render == golden, no diff"

# ---- Superpowers disabled by the user: neither apply nor the doctor break ----
c=$(mk_cell superpowers both)
init_apply "$c" claude-extended
cx "$c" claude plugin disable "superpowers@$OFFICIAL" || _fail "(sp) stub disable"
: > "$c/calls.log"; reapply "$c"; assert_clean_diff "$c"
doctor_strict "$c" STUB_STATE="$T/full-ext.json"
assert_eq "(sp) doctor strict rc" "$RC" "0"
CELLS=$((CELLS + 1)); echo "  superpowers disabled: apply and doctor unaffected"

# ---- policy: the whole-bucket and full state resets appear only as prohibitions (this file is the scanner, excluded), in docs, scripts and tests ----
FORBIDDEN_RE='delete-bucket|state reset'
MARKER_RE='forbidden|zabron|do not|never|must not|nie wolno|NIE|assert_|for bad in'
hits=$(grep -rnEi --exclude=test_fresh_home.sh "$FORBIDDEN_RE" "$AI_ROOT/tests" "$AI_ROOT/docs/workflow" "$AI_ROOT/home" 2>/dev/null || true)
bad_lines=$(printf '%s\n' "$hits" | grep -vE '^$' | grep -viE "$MARKER_RE" || true)
[ -z "$bad_lines" ] || { printf '%s\n' "$bad_lines"; _fail "a broad state reset is mentioned without an explicit prohibition"; }
! grep -rnE --exclude=test_fresh_home.sh 'chezmoi[^#]* state (delete-bucket|reset)' "$AI_ROOT/tests" "$AI_ROOT/home" "$AI_ROOT/docs/workflow/backup.sh" 2>/dev/null | grep -viE "$MARKER_RE" >/dev/null \
    || _fail "an executable broad state reset"

# ---- the real ~/.claude, ~/.codex and the repo are untouched ----
assert_eq "real settings/config untouched" "$(real_sums)" "$real_before"
assert_eq "repo untouched" "$(git -C "$AI_ROOT" status --porcelain 2>/dev/null | sha256sum)" "$repo_before"
echo "  $CELLS cells, all PASS"
