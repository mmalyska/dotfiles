#!/usr/bin/env bash
# Existing hosts (no ai_* keys) must keep rendering exactly the pre-change settings.json.
. "$(dirname "$0")/lib.sh"
expected=$(sorted_json < "$GOLDEN/legacy.settings.json")
for f in legacy-linux legacy-darwin legacy-windows legacy-devcontainer; do
    actual=$(render "$f" home/dot_claude/settings.json.tmpl | sorted_json) || _fail "$f: render failed"
    assert_eq "settings render for $f" "$actual" "$expected"
done
