#!/usr/bin/env bash
# T10: which of the four installer target names each environment gets. A devcontainer is Linux.
# .chezmoi.os cannot be overridden by a fixture, so the matrix renders a copy of .chezmoiignore with a controlled
# substitution (render_ignore.sh); a real `chezmoi managed` on the host confirms it end to end (Linux only).
. "$(dirname "$0")/lib.sh"

RENDER="$AI_ROOT/tests/ai/render_ignore.sh"
NAMES=(100-claude-plugins.sh 110-codex-plugins.sh 100-claude-plugins.ps1 110-codex-plugins.ps1)

# is_ignored <patterns> <target name>: exact pattern or shell glob match against .chezmoiscripts/ai/<name>
is_ignored() {
    local pat
    while IFS= read -r pat; do
        [ -n "$pat" ] || continue
        # shellcheck disable=SC2254  # the pattern is meant to be a glob
        case ".chezmoiscripts/ai/$2" in $pat) return 0;; esac
    done <<< "$1"
    return 1
}

# env label | os | is_devcontainer | expected: active extension
ENVS=("linux|linux|false|sh" "macos|darwin|false|sh" "devcontainer|linux|true|sh" "windows|windows|false|ps1")
declare -a RENDERED
for e in "${ENVS[@]}"; do
    IFS='|' read -r label os devc active <<< "$e"
    pats=$("$RENDER" "$os" "$devc") || _fail "$label: render_ignore failed"
    RENDERED+=("$label")
    for n in "${NAMES[@]}"; do
        if [ "${n##*.}" = "$active" ]; then
            is_ignored "$pats" "$n" && _fail "$label: $n is ignored but must be active"
        else
            is_ignored "$pats" "$n" || _fail "$label: $n is active but must be ignored"
        fi
    done
    # the ai/ directory itself is never ignored wholesale (devcontainer included)
    case "$pats" in
        *".chezmoiscripts/ai/*"*|*".chezmoiscripts/ai"$'\n'*|*".chezmoiscripts/ai") _fail "$label: ai/ is ignored wholesale";;
    esac
    case "$label" in
        linux) PATS_linux=$pats;;
        macos) PATS_macos=$pats;;
        devcontainer) PATS_devcontainer=$pats;;
        windows) PATS_windows=$pats;;
    esac
done
# a devcontainer is Linux: identical treatment of the ai/ scripts
ai_lines() { printf '%s\n' "$1" | grep '^\.chezmoiscripts/ai/' | sort; }
assert_eq "devcontainer == linux for ai/" "$(ai_lines "$PATS_devcontainer")" "$(ai_lines "$PATS_linux")"
assert_eq "macos == linux for ai/" "$(ai_lines "$PATS_macos")" "$(ai_lines "$PATS_linux")"
assert_not_contains "windows ignores no .ps1" "$PATS_windows" ".ps1"
assert_not_contains "linux ignores no .sh installer" "$PATS_linux" "plugins.sh"
# the OS-specific system scripts of the devcontainer branch are unchanged
assert_contains "devcontainer ignores linux scripts" "$PATS_devcontainer" ".chezmoiscripts/linux/*"
assert_not_contains "devcontainer keeps its own scripts" "$PATS_devcontainer" ".chezmoiscripts/devcontainer/*"
assert_contains "non-devcontainer ignores devcontainer scripts" "$PATS_linux" ".chezmoiscripts/devcontainer/*"
# every environment is checked per file: 4 envs x 4 names
echo "  matrix: ${#RENDERED[@]} environments x ${#NAMES[@]} target names"

T=$(new_tmp)
# real chezmoi on a copy of the tree (Linux only: .chezmoi.os is the real one)
if [ "$(uname -s)" != Linux ]; then
    echo "  SKIP real chezmoi managed (host is not Linux; the substitution matrix above is the check)"
    exit 0
fi
SRC="$T/src"; mkdir -p "$SRC"
cp "$AI_ROOT/.chezmoiroot" "$SRC/"
cp -R "$AI_ROOT/home" "$SRC/home"
managed() { # fixture-toml
    chezmoi managed --include=scripts --source "$SRC" --config "$1" --destination "$T/dest" --persistent-state "$T/state.boltdb" --cache "$T/cache" </dev/null
}
sed 's/is_devcontainer = false/is_devcontainer = true/' "$FIXTURES/core-linux.toml" > "$T/core-devcontainer.toml"
grep -q 'is_devcontainer = true' "$T/core-devcontainer.toml" || _fail "devcontainer fixture not generated"
for cfg in "$FIXTURES/core-linux.toml" "$T/core-devcontainer.toml"; do
    out=$(managed "$cfg") || _fail "chezmoi managed failed for $cfg"
    assert_eq "managed ai scripts ($(basename "$cfg"))" "$(printf '%s\n' "$out" | grep '\.chezmoiscripts/ai/' | sort)" \
$'.chezmoiscripts/ai/100-claude-plugins.sh\n.chezmoiscripts/ai/110-codex-plugins.sh'
    assert_not_contains "no .ps1 managed ($(basename "$cfg"))" "$out" ".ps1"
done
