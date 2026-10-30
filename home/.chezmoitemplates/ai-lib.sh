# Shared helpers for the AI workflow installers (bash 3.2 compatible).
# Included by the installer templates via the chezmoi template action. Must not contain template delimiters. Reads no chezmoi data and touches no files until ai_status_write.
# Callers may set AI_ACCEPTED_SHA before ai_summary; it is only recorded in the status file.
AI_FAILS=${AI_FAILS:-0}
AI_SKIPPED=${AI_SKIPPED:-0}

# ai_log <INFO|SKIP|WARN|DONE> <msg>  (stderr)
ai_log() {
    [ "$1" = SKIP ] && AI_SKIPPED=1
    printf '[ai-workflow] %s %s\n' "$1" "$2" >&2
}

# ai_have <cmd>
ai_have() { command -v "$1" >/dev/null 2>&1; }

# ai_soft <description> -- <cmd...>: a failing command is a WARN, never an error.
ai_soft() {
    local desc=$1
    shift
    [ "${1:-}" = "--" ] && shift
    if ! "$@"; then
        ai_log WARN "$desc failed"
        AI_FAILS=$((AI_FAILS + 1))
    fi
    return 0
}

# ai_marketplace_head <dir>: HEAD commit of a marketplace checkout, empty when unavailable.
ai_marketplace_head() {
    local h
    if h=$(git -C "$1" rev-parse HEAD 2>/dev/null); then printf '%s\n' "$h"; fi
}

# ai_status_write <harness> <ok|partial|skipped> <fails>
ai_status_write() {
    local dir="${XDG_STATE_HOME:-$HOME/.local/state}/ai-workflow" tmp
    mkdir -p "$dir" || return 0
    tmp="$dir/.$1.status.$$"
    {
        printf 'result=%s\n' "$2"
        printf 'fails=%s\n' "$3"
        printf 'accepted_sha=%s\n' "${AI_ACCEPTED_SHA:-}"
        printf 'time=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$tmp" && mv "$tmp" "$dir/$1.status"
}

# ai_summary <harness>: last line of every installer; always exit status 0.
ai_summary() {
    local result=ok
    if [ "$AI_FAILS" -gt 0 ]; then
        result=partial
    elif [ "$AI_SKIPPED" = 1 ]; then
        result=skipped
    fi
    ai_log DONE "$1 fails=$AI_FAILS"
    ai_status_write "$1" "$result" "$AI_FAILS" || ai_log WARN "could not write status for $1"
    return 0
}
