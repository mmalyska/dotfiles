#!/usr/bin/env bash
# Backup of the managed AI settings and the CLI plugin state, taken before an upgrade or a profile change.
# Copies only; reads the sources and writes below ${XDG_STATE_HOME:-~/.local/state}/ai-workflow-backup/<UTC>/ :
#   settings.json         <- ${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json   (overwritten by every chezmoi apply)
#   config.toml           <- ${CODEX_HOME:-~/.codex}/config.toml
#   claude-plugins.json   <- claude plugin list --json
#   codex-plugins.txt     <- codex plugin list
# A missing source or CLI is reported as SKIP and does not stop the others. Exit 1 only when nothing could be written.
set -u

umask 077
stamp=$(date -u +%Y%m%dT%H%M%SZ)
root="${XDG_STATE_HOME:-$HOME/.local/state}/ai-workflow-backup"
dest="$root/$stamp"
n=1
while [ -e "$dest" ]; do n=$((n + 1)); dest="$root/$stamp-$n"; done
mkdir -p "$dest" || { echo "backup: cannot create $dest" >&2; exit 1; }

saved=0
copy_file() { # <source> <name>
    if [ -f "$1" ]; then
        cp -p "$1" "$dest/$2" && { echo "SAVED $2 <- $1"; saved=$((saved + 1)); return; }
        echo "WARN could not copy $1" >&2
    else
        echo "SKIP $2: $1 not found"
    fi
}
capture() { # <name> <cli> <args...>
    local name=$1 cli=$2
    shift 2
    if ! command -v "$cli" >/dev/null 2>&1; then echo "SKIP $name: $cli CLI not found"; return; fi
    if "$cli" "$@" > "$dest/$name.tmp" 2>/dev/null; then
        mv "$dest/$name.tmp" "$dest/$name" && { echo "SAVED $name <- $cli $*"; saved=$((saved + 1)); return; }
    fi
    rm -f "$dest/$name.tmp"
    echo "WARN $cli $* failed, $name not saved" >&2
}

copy_file "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" settings.json
copy_file "${CODEX_HOME:-$HOME/.codex}/config.toml" config.toml
capture claude-plugins.json claude plugin list --json
capture codex-plugins.txt codex plugin list

echo "backup: $saved file(s) in $dest"
if [ "$saved" = 0 ]; then rmdir "$dest" 2>/dev/null; echo "backup: nothing to save" >&2; exit 1; fi
exit 0
