#!/usr/bin/env bash
# The harness must never touch the real HOME or the repo: render + init run, then compare snapshots.
. "$(dirname "$0")/lib.sh"
# Only paths the harness could plausibly write; the rest of the real HOME is busy with other processes.
snap() { (cd "$1" && find .config/chezmoi .local/share/chezmoi .local/state/ai-workflow .claude/settings.json .codex -printf '%p %s %T@\n' 2>/dev/null | sort | sha256sum); }
[ -n "${AI_REAL_HOME:-}" ] || _fail "AI_REAL_HOME not exported by run.sh"
case "$HOME" in "$AI_REAL_HOME") _fail "HOME is the real home";; esac
before=$(snap "$AI_REAL_HOME"); repo_before=$(git -C "$AI_ROOT" status --porcelain | sha256sum)
render core-linux home/dot_claude/settings.json.tmpl >/dev/null
resolve_profile legacy-linux >/dev/null
[ "$(snap "$AI_REAL_HOME")" = "$before" ] || _fail "real HOME changed"
[ "$(git -C "$AI_ROOT" status --porcelain | sha256sum)" = "$repo_before" ] || _fail "repo changed"
