#!/usr/bin/env bash
# T13 layer B (native, opt-in AI_NATIVE_TESTS=1): the fresh-environment matrix with the REAL claude and codex CLIs and the real network.
# Each cell: `chezmoi init --apply` into HOME=$REAL/.cache/ai-e2e.XXXX (outside /tmp; Codex refuses aliases there) with its own
# CLAUDE_CONFIG_DIR and CODEX_HOME, on a copy of the tree without system scripts. No model turn is made.
# Result per cell: PASS | FAIL | NOT RUN <reason>. NOT RUN only when a real CLI, the network or the platform is missing.
# Exit: 77 = everything NOT RUN, 1 = at least one FAIL, 0 = no FAIL and at least one PASS (NOT RUN cells are listed, never counted as PASS).
. "$(dirname "$0")/lib.sh"

REAL="${HOME:?}"
PASS=0; NOTRUN=0; FAILED=0
cell_pass() { PASS=$((PASS + 1)); echo "PASS cell $1"; }
cell_notrun() { NOTRUN=$((NOTRUN + 1)); echo "NOT RUN cell $1: $2"; }
cell_fail() { FAILED=$((FAILED + 1)); echo "FAIL cell $1: $2"; }

real_claude=$(command -v claude 2>/dev/null || true); real_codex=$(command -v codex 2>/dev/null || true)
[ -n "$real_claude" ] && real_claude=$(readlink -f "$real_claude" 2>/dev/null || echo "$real_claude")
[ -n "$real_codex" ] && real_codex=$(readlink -f "$real_codex" 2>/dev/null || echo "$real_codex")
if [ -z "$real_claude$real_codex" ]; then echo "NOT RUN all: neither a real claude nor a real codex CLI on PATH"; exit 77; fi
if ! git ls-remote --exit-code https://github.com/mmalyska/claude-plugins.git HEAD >/dev/null 2>&1; then
    echo "NOT RUN all: github.com/mmalyska/claude-plugins not reachable"; exit 77
fi
case "$(uname -s)" in Linux|Darwin) ;; *) echo "NOT RUN all: native layer supports Linux and macOS shells only"; exit 77;; esac

mkdir -p "$REAL/.cache"
ROOT=$(mktemp -d "$REAL/.cache/ai-e2e.XXXX")
trap 'rm -rf "$ROOT"' EXIT
real_sums() { (cd "$REAL" && sha256sum .claude/settings.json .codex/config.toml 2>/dev/null; true); }
real_before=$(real_sums)
CHEZMOI_BIN=$(command -v chezmoi)

SRC="$ROOT/src"; mkdir -p "$SRC"
rsync -a --exclude .git --exclude .worktrees "$AI_ROOT/" "$SRC/"
rm -rf "$SRC"/home/.chezmoiscripts/{linux,macos,windows,devcontainer}
find "$SRC/home" -maxdepth 1 -name 'run_once_*' -delete

cell_env() { # <cell dir> <cmd...>
    local c=$1; shift
    env HOME="$c/home" XDG_CONFIG_HOME="$c/home/.config" XDG_DATA_HOME="$c/home/.local/share" XDG_CACHE_HOME="$c/home/.cache" \
        XDG_STATE_HOME="$c/home/.local/state" CLAUDE_CONFIG_DIR="$c/home/.claude" CODEX_HOME="$c/home/.codex" PATH="$c/bin:$BASE_PATH" "$@"
}
mk_cell() { # <name> <both|claude|codex|none>
    local c="$ROOT/$1"
    mkdir -p "$c/home/.codex" "$c/bin"   # Codex refuses a CODEX_HOME that does not exist
    ln -s "$CHEZMOI_BIN" "$c/bin/chezmoi"
    case "$2" in both|claude) [ -z "$real_claude" ] || ln -s "$real_claude" "$c/bin/claude";; esac
    case "$2" in both|codex) [ -z "$real_codex" ] || ln -s "$real_codex" "$c/bin/codex";; esac
    echo "$c"
}
cz() { cell_env "$1" "$TIMEOUT" 600 chezmoi --source "$SRC" "${@:2}" </dev/null; }
render_tpl() { cell_env "$1" chezmoi --source "$SRC" execute-template < "$2"; } # <cell> <template>: stdout
cell_init() { # <cell> <profile> [flags]
    local c=$1 p=$2; shift 2
    cz "$c" init --apply --promptDefaults --promptChoice "$PROMPT_PROFILE=$p" "${PRE_FLAGS[@]}" "$@" >"$c/init.out" 2>&1
}
ids_of() { sed -n 's/.*"\(id\|pluginId\)": *"\([^"]*\)".*/\2/p'; }
sum_file() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

run_cell() { # <profile> <cli-set>; any failed assertion -> FAIL (subshell), missing real CLI -> NOT RUN
    local p=$1 s=$2 name="$1/$2" c n_own n_ext
    case "$s" in both|claude) [ -n "$real_claude" ] || { cell_notrun "$name" "no real claude CLI"; return; };; esac
    case "$s" in both|codex) [ -n "$real_codex" ] || { cell_notrun "$name" "no real codex CLI"; return; };; esac
    case "$p" in minimal) n_own=2; n_ext=0;; core) n_own=12; n_ext=0;; *) n_own=12; n_ext=4;; esac
    c=$(mk_cell "$p-$s" "$s")
    local why rc
    why=$( (
        set -u
        cell_init "$c" "$p" || { tail -5 "$c/init.out"; echo "init --apply failed"; exit 1; }
        python3 -I -c '
import json, sys
e = json.load(open(sys.argv[1]))["enabledPlugins"]
sys.exit(0 if len(e) == int(sys.argv[2]) else 1)' "$c/home/.claude/settings.json" $((n_own + n_ext)) || { echo "settings.json plugin count"; exit 1; }
        if [ "$s" = both ] || [ "$s" = claude ]; then
            [ "$(sed -n 's/^result=//p' "$c/home/.local/state/ai-workflow/claude.status")" = ok ] || { echo "claude.status is not ok"; exit 1; }
            list=$(cell_env "$c" claude plugin list --json | ids_of)
            [ "$(printf '%s\n' "$list" | grep -c "@$OWN\$")" = "$n_own" ] || { echo "claude own plugins != $n_own"; exit 1; }
            [ "$(printf '%s\n' "$list" | grep -c "@$OFFICIAL\$")" = "$n_ext" ] || { echo "claude extras != $n_ext"; exit 1; }
            [ "$(git -C "$c/home/.claude/plugins/marketplaces/$OWN" rev-parse HEAD)" = "$SHA" ] || { echo "claude marketplace HEAD != accepted sha"; exit 1; }
        else
            [ "$(sed -n 's/^result=//p' "$c/home/.local/state/ai-workflow/claude.status")" = skipped ] || { echo "claude.status is not skipped"; exit 1; }
            [ ! -e "$c/home/.claude/plugins" ] || { echo "claude plugins dir exists without a claude CLI"; exit 1; }
        fi
        if [ "$s" = both ] || [ "$s" = codex ]; then
            [ "$(sed -n 's/^result=//p' "$c/home/.local/state/ai-workflow/codex.status")" = ok ] || { echo "codex.status is not ok"; exit 1; }
            grep -q "ref = \"$SHA\"" "$c/home/.codex/config.toml" || { echo "codex ref not pinned"; exit 1; }
            grep -q "^\[plugins.\"git-workflows@$OWN\"\]" "$c/home/.codex/config.toml" || { echo "codex git-workflows not enabled"; exit 1; }
            [ "$(grep -c "^\[plugins\.\".*@$OWN\"\]" "$c/home/.codex/config.toml")" = "$n_own" ] || { echo "codex plugin count != $n_own"; exit 1; }
            ! grep -q 'superpowers' "$c/home/.codex/config.toml" || { echo "codex got superpowers"; exit 1; }
        else
            [ "$(sed -n 's/^result=//p' "$c/home/.local/state/ai-workflow/codex.status")" = skipped ] || { echo "codex.status is not skipped"; exit 1; }
        fi
        # settings.json: the claude CLI rewrites it (key order, whitespace) while installing plugins. Content must stay equal.
        render_tpl "$c" "$SRC/home/dot_claude/settings.json.tmpl" > "$c/settings.rendered.json"
        python3 -I -c '
import json, sys
sys.exit(0 if json.load(open(sys.argv[1])) == json.load(open(sys.argv[2])) else 1)' "$c/settings.rendered.json" "$c/home/.claude/settings.json" \
            || { echo "settings.json content differs from the managed render after the installers ran"; exit 1; }
        # second apply: exit 0 and empty diff. KNOWN: when the claude CLI rewrote settings.json, chezmoi stops on its
        # "has changed since chezmoi last wrote it" prompt (no TTY: exit 1). Accepted only for exactly that case, then --force.
        if ! cz "$c" apply >"$c/apply2.out" 2>&1; then
            if ! grep -q 'settings.json has changed since chezmoi last wrote it' "$c/apply2.out" || { [ "$s" != both ] && [ "$s" != claude ]; }; then
                tail -5 "$c/apply2.out"; echo "second apply failed"; exit 1
            fi
            others=$(cz "$c" diff 2>&1 | sed -n 's/^diff --git a\/\(.*\) b\/.*/\1/p' | grep -v '^.claude/settings.json$' || true)
            [ -z "$others" ] || { echo "second apply: diff beyond settings.json: $others"; exit 1; }
            echo "KNOWN plain second apply stops at settings.json (rewritten by the claude CLI, same content); continuing with --force"
            cz "$c" apply --force >"$c/apply2f.out" 2>&1 || { tail -5 "$c/apply2f.out"; echo "second apply --force failed"; exit 1; }
        fi
        [ -z "$(cz "$c" diff 2>&1)" ] || { echo "chezmoi diff not empty after the second apply"; exit 1; }
        cfg_before=$(sum_file "$c/home/.codex/config.toml"); set_before=$(sum_file "$c/home/.claude/settings.json")
        for t in 100-claude-plugins 110-codex-plugins; do
            render_tpl "$c" "$SRC/home/.chezmoiscripts/ai/run_onchange_after_$t.sh.tmpl" > "$c/$t.sh"
            grep -q 'ai_summary' "$c/$t.sh" || { echo "rendered $t is empty"; exit 1; }
            cell_env "$c" bash "$c/$t.sh" >"$c/$t.out" 2>&1 || { echo "$t rerun failed"; exit 1; }
        done
        [ "$(sum_file "$c/home/.codex/config.toml")" = "$cfg_before" ] || { echo "second run changed config.toml"; exit 1; }
        [ "$(sum_file "$c/home/.claude/settings.json")" = "$set_before" ] || { echo "second run changed settings.json"; exit 1; }
        if [ "$s" = both ] || [ "$s" = claude ]; then
            grep -q 'already' "$c/100-claude-plugins.out" || { echo "claude rerun did not report already-installed"; exit 1; }
            [ "$(cell_env "$c" claude plugin list --json | ids_of | wc -l | tr -d ' ')" = $((n_own + n_ext)) ] || { echo "claude plugin set changed on rerun"; exit 1; }
        fi
        cell_env "$c" bash "$c/home/.local/bin/ai-workflow-doctor" --strict >"$c/doctor.out" 2>&1 || { tail -15 "$c/doctor.out"; echo "doctor --strict exit != 0"; exit 1; }
        ! grep -rEi 'STANDARD|SOLO|topology|ghp_|sk-[a-z0-9]|api[_-]?key|password' "$c/home/.claude/settings.json" >/dev/null || { echo "workflow vocabulary or secret in settings.json"; exit 1; }
    ) 2>&1 ); rc=$?
    printf '%s\n' "$why" | grep '^KNOWN' || true
    if [ $rc = 0 ]; then cell_pass "$name"; else cell_fail "$name" "$(printf '%s' "$why" | tail -8 | tr '\n' ' ')"; fi
    rm -rf "$c"
}

for p in minimal core claude-extended; do for s in both claude codex none; do run_cell "$p" "$s"; done; done

# ---- flags ----
flag_cell() { # <name> <claude> <codex>
    local c why rc; c=$(mk_cell "$1" both)
    why=$( (
        cell_init "$c" core --promptBool "$PROMPT_CLAUDE=$2" --promptBool "$PROMPT_CODEX=$3" || { tail -5 "$c/init.out"; echo "init failed"; exit 1; }
        r() { sed -n 's/^result=//p' "$c/home/.local/state/ai-workflow/$1.status"; }
        if [ "$2" = false ]; then [ "$(r claude)" = skipped ] && [ ! -e "$c/home/.claude/plugins" ] || { echo "claude not skipped"; exit 1; }; else [ "$(r claude)" = ok ] || { echo "claude not ok"; exit 1; }; fi
        if [ "$3" = false ]; then [ "$(r codex)" = skipped ] && [ ! -e "$c/home/.codex/config.toml" ] || { echo "codex not skipped"; exit 1; }; else [ "$(r codex)" = ok ] || { echo "codex not ok"; exit 1; }; fi
    ) 2>&1 ); rc=$?
    if [ $rc = 0 ]; then cell_pass "$1"; else cell_fail "$1" "$(printf '%s' "$why" | tail -5 | tr '\n' ' ')"; fi
    rm -rf "$c"
}
if [ -n "$real_claude" ] && [ -n "$real_codex" ]; then
    flag_cell flags/no-claude false true; flag_cell flags/no-codex true false; flag_cell flags/no-both false false
else
    cell_notrun "flags/*" "needs both real CLIs"
fi

# ---- no network: a proxy that refuses connections. NOT RUN when a CLI ignores it (the network cannot be cut here) ----
if [ -n "$real_claude" ] && [ -n "$real_codex" ]; then
    c=$(mk_cell offline both)
    why=$( (
        cz_off() { cell_env "$c" env HTTPS_PROXY=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 http_proxy=http://127.0.0.1:9 ALL_PROXY=http://127.0.0.1:9 GIT_TERMINAL_PROMPT=0 "$TIMEOUT" 600 chezmoi --source "$SRC" "$@" </dev/null; }
        cz_off init --apply --promptDefaults --promptChoice "$PROMPT_PROFILE=core" "${PRE_FLAGS[@]}" >"$c/init.out" 2>&1 || { tail -5 "$c/init.out"; echo "init --apply must exit 0 offline"; exit 1; }
        cr=$(sed -n 's/^result=//p' "$c/home/.local/state/ai-workflow/claude.status"); xr=$(sed -n 's/^result=//p' "$c/home/.local/state/ai-workflow/codex.status")
        if [ "$cr" = ok ] || [ "$xr" = ok ]; then echo "CANNOT-BLOCK claude=$cr codex=$xr"; exit 99; fi
        [ "$cr" = partial ] && [ "$xr" = partial ] || { echo "statuses claude=$cr codex=$xr"; exit 1; }
        cell_env "$c" bash "$c/home/.local/bin/ai-workflow-doctor" --strict >"$c/doctor.out" 2>&1 && { echo "doctor --strict exit 0 after a failed install"; exit 1; }
        exit 0
    ) 2>&1 ); rc=$?
    case $rc in 0) cell_pass offline;; 99) cell_notrun offline "network cannot be blocked for the real CLIs here (proxy ignored): ${why##*CANNOT-BLOCK }";; *) cell_fail offline "$(printf '%s' "$why" | tail -5 | tr '\n' ' ')";; esac
    rm -rf "$c"
else
    cell_notrun offline "needs both real CLIs"
fi

# ---- Codex: `marketplace add --ref <other>` over an existing entry (behaviour recorded for the runbook) ----
if [ -n "$real_codex" ]; then
    c=$(mk_cell codexref codex)
    ( cell_init "$c" minimal || exit 1
      cfg="$c/home/.codex/config.toml"
      cell_env "$c" codex plugin marketplace add mmalyska/claude-plugins --ref main >"$c/ref.out" 2>&1; rc=$?
      echo "OBSERVED codex marketplace add --ref main over an entry pinned to $SHA: exit=$rc ref_after=$(sed -n 's/^ref = //p' "$cfg" | head -1) first_line=$(head -1 "$c/ref.out")"
      cell_env "$c" bash -c 'codex plugin marketplace remove mmalyska-claude-plugins && codex plugin marketplace add mmalyska/claude-plugins --ref '"$SHA" >"$c/readd.out" 2>&1; rc2=$?
      echo "OBSERVED remove + add --ref <accepted>: exit=$rc2 ref_after=$(sed -n 's/^ref = //p' "$cfg" | head -1)"
    ) 2>&1 | grep -E '^OBSERVED|failed' || true
    rm -rf "$c"
fi

[ "$(real_sums)" = "$real_before" ] || { echo "FAIL real ~/.claude/settings.json or ~/.codex/config.toml changed"; FAILED=$((FAILED + 1)); }
echo "RESULT pass=$PASS notrun=$NOTRUN fail=$FAILED"
[ "$FAILED" = 0 ] || exit 1
[ "$PASS" -gt 0 ] || exit 77
exit 0
