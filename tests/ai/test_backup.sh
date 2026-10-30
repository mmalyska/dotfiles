#!/usr/bin/env bash
# docs/workflow/backup.sh (T11b) on stub CLIs: copies four files, never changes its sources, degrades per missing item.
. "$(dirname "$0")/lib.sh"

T=$(new_tmp)
BACKUP="$AI_ROOT/docs/workflow/backup.sh"
bash -n "$BACKUP" || _fail "bash -n backup.sh"
if command -v shellcheck >/dev/null; then shellcheck -s bash "$BACKUP" || _fail "shellcheck backup.sh"; else echo "  NOT RUN shellcheck (not installed)"; fi

H="$T/home"; mkdir -p "$H/.claude" "$H/.codex"
printf '{"model":"opusplan"}\n' > "$H/.claude/settings.json"
printf 'model = "x"\n[marketplaces.m]\nref = "r"\n' > "$H/.codex/config.toml"
ids=(); for p in "${OWN_IDS[@]}"; do ids+=("$p@$OWN"); done
write_state "$T/state.json" "${ids[@]}"
sums() { (cd "$H" && sha256sum .claude/settings.json .codex/config.toml); }
before=$(sums)

run_backup() { # <path> [VAR=value...]; sets RC OUT LOG
    local p=$1; shift
    LOG="$T/calls.$RANDOM.log"; : > "$LOG"
    OUT=$(env -u XDG_STATE_HOME -u CLAUDE_CONFIG_DIR -u CODEX_HOME HOME="$H" PATH="$p" AI_TEST_LOG="$LOG" "$@" bash "$BACKUP" 2>&1); RC=$?
}

# all four present
run_backup "$STUBS:$BASE_PATH" STUB_STATE="$T/state.json"
assert_eq "rc" "$RC" "0"
D=$(find "$H/.local/state/ai-workflow-backup" -mindepth 1 -maxdepth 1 -type d)
assert_eq "one backup dir" "$(printf '%s\n' "$D" | wc -l | tr -d ' ')" "1"
case "$(basename "$D")" in [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z*) ;; *) _fail "dir name is not a UTC stamp: $D";; esac
assert_eq "four files" "$(find "$D" -type f | wc -l | tr -d ' ')" "4"
for f in settings.json config.toml claude-plugins.json codex-plugins.txt; do [ -s "$D/$f" ] || _fail "missing/empty $f"; done
cmp -s "$D/settings.json" "$H/.claude/settings.json" || _fail "settings.json differs from the source"
cmp -s "$D/config.toml" "$H/.codex/config.toml" || _fail "config.toml differs from the source"
assert_contains "claude list content" "$(cat "$D/claude-plugins.json")" "git-workflows@$OWN"
assert_eq "sources unchanged" "$(sums)" "$before"
assert_calls "only list calls" "$LOG" '^(claude|codex) plugin list' 2
assert_calls "no mutating calls" "$LOG" '(add|install|remove|uninstall|disable|update|marketplace)' 0
[ -z "$(find "$D" -name '*.tmp')" ] || _fail "temp file left behind"
[ "$(stat -c %a "$D" 2>/dev/null || stat -f %Lp "$D")" = 700 ] || _fail "backup dir is not private (0700)"

# a second run never overwrites the first (same second or not)
run_backup "$STUBS:$BASE_PATH" STUB_STATE="$T/state.json"
assert_eq "two backup dirs" "$(find "$H/.local/state/ai-workflow-backup" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "2"

# no CLI on PATH: files still saved, CLI items SKIP, exit 0
rm -rf "$H/.local"
run_backup "$BASE_PATH"
assert_eq "no-cli rc" "$RC" "0"
assert_contains "claude skip" "$OUT" "SKIP claude-plugins.json: claude CLI not found"
assert_contains "codex skip" "$OUT" "SKIP codex-plugins.txt: codex CLI not found"
D=$(find "$H/.local/state/ai-workflow-backup" -mindepth 1 -maxdepth 1 -type d)
assert_eq "no-cli files" "$(find "$D" -type f | wc -l | tr -d ' ')" "2"

# a failing CLI is a WARN, the rest is saved
rm -rf "$H/.local"
run_backup "$STUBS:$BASE_PATH" STUB_FAIL="plugin+list"
assert_eq "fail rc" "$RC" "0"
assert_contains "fail warn" "$OUT" "WARN claude plugin list --json failed"
D=$(find "$H/.local/state/ai-workflow-backup" -mindepth 1 -maxdepth 1 -type d)
[ -z "$(find "$D" -name '*.tmp')" ] || _fail "temp file left behind after failure"

# nothing to save: exit 1 and no empty directory
H2="$T/home2"; mkdir -p "$H2"
OUT=$(env -u XDG_STATE_HOME HOME="$H2" PATH="$BASE_PATH" bash "$BACKUP" 2>&1); RC=$?
assert_eq "empty rc" "$RC" "1"
[ -z "$(find "$H2/.local/state/ai-workflow-backup" -mindepth 1 -type d 2>/dev/null)" ] || _fail "empty backup dir left behind"
assert_eq "sources unchanged at end" "$(sums)" "$before"
