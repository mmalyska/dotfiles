#!/usr/bin/env bash
# Shared helpers for tests/ai. Source from test_*.sh; do not execute.
# shellcheck disable=SC2034  # variables are consumed by the sourcing test scripts
# Prompt texts are part of the contract with `chezmoi init --promptChoice/--promptBool`
# (flags are keyed by prompt text, not by data key) and must match home/.chezmoi.toml.tmpl.
PROMPT_PROFILE="AI profile"
PROMPT_TEAMS="Enable Claude agent teams"

AI_ROOT="${AI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
FIXTURES="$AI_ROOT/tests/ai/fixtures"
GOLDEN="$AI_ROOT/tests/ai/golden"
AI_TMPS=()

_fail() { echo "  ASSERT FAILED: $*" >&2; exit 1; }

assert_eq() { # name actual expected  (multi-line values are reported as a diff)
    [ "$2" = "$3" ] && return 0
    echo "  ASSERT FAILED: $1" >&2
    diff <(printf '%s\n' "$3") <(printf '%s\n' "$2") | head -20 | sed 's/^/    /' >&2
    exit 1
}
assert_contains() { # name haystack needle
    case "$2" in *"$3"*) ;; *) _fail "$1: [$3] not found";; esac
}
assert_not_contains() { # name haystack needle
    case "$2" in *"$3"*) _fail "$1: unexpected [$3] found";; esac
}
assert_calls() { # name logfile extended-regex expected-count
    local n
    n=$(grep -cE "$3" "$2" 2>/dev/null || true)
    [ "${n:-0}" = "$4" ] || _fail "$1: expected $4 calls matching /$3/, got ${n:-0}"
}

# new_tmp: private temp dir removed on exit (only directories created here).
new_tmp() {
    local d
    d=$(mktemp -d)
    AI_TMPS+=("$d")
    printf '%s\n' "$d"
}
_cleanup() { local d; for d in "${AI_TMPS[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap _cleanup EXIT

# render <fixture-name> <template-path-relative-to-repo>  (stdout)
render() {
    chezmoi --source "$AI_ROOT" --config "$FIXTURES/$1.toml" execute-template \
        < "$AI_ROOT/$2"
}

# sorted_json: normalise JSON on stdin (valid JSON required)
sorted_json() { python3 -I -m json.tool --sort-keys; }

# Remaining prompt texts of .chezmoi.toml.tmpl (see PROMPT_PROFILE/PROMPT_TEAMS above).
PROMPT_CLAUDE="Configure Claude Code plugins"
PROMPT_CODEX="Configure Codex plugins"
PROMPT_OPENCODE="Enable OpenCode (experimental, not implemented)"
# Prompts that exist since before the AI workflow work; answered explicitly in init tests.
PRE_FLAGS=(--promptString "Email address for git=test@example.invalid"
           --promptString "User name for git=Test User"
           --promptBool "If work machine=false")

# resolve_profile <fixture>  -> JSON from ai-profile.tmpl
resolve_profile() {
    chezmoi --source "$AI_ROOT" --config "$FIXTURES/$1.toml" execute-template \
        '{{ includeTemplate "ai-profile.tmpl" . }}'
}
# toml_get <file> <key>  -> value of [data].<key> as plain text (true/false/string)
toml_get() {
    python3 -I -c '
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))["data"]
v = d[sys.argv[2]]
print(str(v).lower() if isinstance(v, bool) else v)' "$1" "$2"
}

# ---- installer helpers (stub CLIs). Callers set T (new_tmp) first. ----
STUBS="$AI_ROOT/tests/ai/stubs"
CHEZMOI=$(command -v chezmoi)
BASE_PATH=/usr/bin:/bin
# absolute path: the installers run under a restricted PATH (env PATH=... timeout would not find a Homebrew coreutils timeout)
TIMEOUT=$(command -v timeout || command -v gtimeout || echo timeout)
OWN=mmalyska-claude-plugins
OFFICIAL=claude-plugins-official
SHA=25d785abee26ca7a3c87e8311f46e8a90f225301
CLAUDE_TPL=home/.chezmoiscripts/ai/run_onchange_after_100-claude-plugins.sh.tmpl
# render_script <fixture> <path> -> file with the rendered installer
render_script() {
    PATH=$2 "$CHEZMOI" --source "$AI_ROOT" --config "$FIXTURES/$1.toml" execute-template < "$AI_ROOT/$CLAUDE_TPL" > "$T/$1.sh"
    echo "$T/$1.sh"
}
OWN_IDS=(personal-essentials git-workflows development-lifecycle dotnet frontend backend devops security agent-toolkit renovate devcontainer android)
EXTRA_IDS=(superpowers code-simplifier context7 claude-md-management)
# write_state <file> <plugin@marketplace...>: `claude plugin list --json` shaped state
write_state() {
    local f=$1 first=1 id; shift
    { echo "["; for id in "$@"; do [ $first = 1 ] || echo ","; first=0; printf '  {"id": "%s", "scope": "user", "enabled": true}' "$id"; done; echo; echo "]"; } > "$f"
}
write_marketplaces() { # file name...
    local f=$1 first=1 n; shift
    { echo "["; for n in "$@"; do [ $first = 1 ] || echo ","; first=0; printf '  {\n    "name": "%s",\n    "source": "github"\n  }' "$n"; done; echo; echo "]"; } > "$f"
}
# run_installer <script> [VAR=value...]: runs with stubs on PATH, fresh HOME, log in $LOG; sets RC and OUT
run_installer() {
    local script=$1; shift
    HOMEDIR="$T/home.$RANDOM"; LOG="$T/calls.$RANDOM.log"; : > "$LOG"
    OUT=$(env -u XDG_STATE_HOME -u CLAUDE_CONFIG_DIR HOME="$HOMEDIR" PATH="$STUBS:$BASE_PATH" AI_TEST_LOG="$LOG" "$@" bash "$script" 2>&1)
    RC=$?
}
status_of() { cat "$HOMEDIR/.local/state/ai-workflow/claude.status"; }
