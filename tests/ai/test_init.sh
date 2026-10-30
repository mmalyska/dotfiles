#!/usr/bin/env bash
# chezmoi init: new vs existing host (D-G). Runs on a copy of the tree, never applies, never prompts.
. "$(dirname "$0")/lib.sh"

T=$(new_tmp)
BEFORE=$(git -C "$AI_ROOT" status --porcelain 2>/dev/null | sha256sum)
SRC="$T/src"; mkdir -p "$SRC"
rsync -a --exclude .git --exclude .worktrees "$AI_ROOT/" "$SRC/"

# init_run <config> [flags...]  (no TTY, bounded, nothing applied)
init_run() {
    local cfg=$1; shift
    timeout 30 chezmoi init --source "$SRC" --config "$cfg" --destination "$T/dest" \
        --cache "$T/cache" --persistent-state "$T/state.boltdb" "$@" </dev/null
}
keys() { # config -> "profile/teams/claude/codex/opencode"
    printf '%s/%s/%s/%s/%s' "$(toml_get "$1" ai_profile)" "$(toml_get "$1" ai_agent_teams)" \
        "$(toml_get "$1" ai_claude)" "$(toml_get "$1" ai_codex)" "$(toml_get "$1" ai_opencode)"
}
legacy_cfg() { # path: pre-feature config
    cat > "$1" <<'T'
[data]
    email = "test@example.invalid"
    user = "Test User"
    is_work = false
    is_wsl = false
    is_arch = true
    is_devcontainer = false
T
}

# 6a. prompt constants match the template
for p in "$PROMPT_PROFILE" "$PROMPT_TEAMS" "$PROMPT_CLAUDE" "$PROMPT_CODEX" "$PROMPT_OPENCODE"; do
    grep -qF "\"$p\"" "$AI_ROOT/home/.chezmoi.toml.tmpl" || _fail "prompt text [$p] not in .chezmoi.toml.tmpl"
done

# 1. new host, defaults
C1="$T/new1.toml"
init_run "$C1" --promptDefaults || _fail "init new host failed"
assert_eq "new host defaults" "$(keys "$C1")" "core/false/true/true/false"

# 2. new host, explicit answers
C2="$T/new2.toml"
init_run "$C2" --promptDefaults "${PRE_FLAGS[@]}" --promptChoice "$PROMPT_PROFILE=minimal" \
    --promptBool "$PROMPT_TEAMS=false" || _fail "init new host (flags) failed"
assert_eq "new host minimal" "$(keys "$C2")" "minimal/false/true/true/false"

# 3. existing host, apply path without init: render still equals golden
assert_eq "existing host render" \
    "$(render legacy-linux home/dot_claude/settings.json.tmpl | sorted_json)" \
    "$(sorted_json < "$GOLDEN/legacy.settings.json")"

# 4. existing host, init -> explicit claude-extended, stable on second init
C4="$T/legacy4.toml"; legacy_cfg "$C4"
init_run "$C4" --promptDefaults || _fail "init existing host failed"
assert_eq "legacy init" "$(keys "$C4")" "claude-extended/true/true/true/false"
C4b="$T/legacy4b.toml"; legacy_cfg "$C4b"
init_run "$C4b" "${PRE_FLAGS[@]}" || _fail "init existing host without flags failed"
assert_eq "legacy init no flags" "$(keys "$C4b")" "claude-extended/true/true/true/false"
init_run "$C4" --promptDefaults || _fail "second init failed"
assert_eq "legacy init stable" "$(keys "$C4")" "claude-extended/true/true/true/false"

# 5. migration: explicit re-prompt on an existing host
C5="$T/legacy5.toml"; legacy_cfg "$C5"
init_run "$C5" --prompt --promptDefaults --promptChoice "$PROMPT_PROFILE=core" --promptBool "$PROMPT_TEAMS=false" \
    "${PRE_FLAGS[@]}" || _fail "migration init failed"
assert_eq "migration" "$(keys "$C5")" "core/false/true/true/false"
init_run "$C5" --promptDefaults || _fail "init after migration failed"
assert_eq "migration stable" "$(keys "$C5")" "core/false/true/true/false"

# 6b. flag keyed by data key (wrong form) does not change the result
C6="$T/new6.toml"
init_run "$C6" --promptDefaults --promptChoice "ai_profile=minimal" 2>/dev/null || true
if [ -f "$C6" ]; then
    assert_eq "wrong flag form ignored" "$(toml_get "$C6" ai_profile)" "core"
fi

# 7. existing values preserved and config parses
assert_eq "email preserved" "$(toml_get "$C4" email)" "test@example.invalid"

# 8. nothing written outside $T (source tree untouched)
[ "$(git -C "$AI_ROOT" status --porcelain 2>/dev/null | sha256sum)" = "$BEFORE" ] || _fail "init modified the repo"
