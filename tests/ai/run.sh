#!/usr/bin/env bash
# Runs tests/ai/test_*.sh, each with a private throw-away HOME.
# Variables that point a CLI at a config outside HOME are cleared, so a test cannot read the real one.
# Native tests (tests/ai/e2e-*.sh) run only with AI_NATIVE_TESTS=1, otherwise NOT RUN.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
export AI_ROOT=$ROOT
REAL_HOME=${HOME:-}
failed=0
for t in "$ROOT"/tests/ai/test_*.sh; do
    name=$(basename "$t" .sh)
    tmp=$(mktemp -d)
    if env -u CODEX_HOME -u CLAUDE_CONFIG_DIR -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME \
        HOME="$tmp" AI_REAL_HOME="$REAL_HOME" bash "$t"; then
        echo "PASS $name"
    else
        echo "FAIL $name"
        failed=1
    fi
    rm -rf "$tmp"
done
for t in "$ROOT"/tests/ai/e2e-*.sh; do
    [ -e "$t" ] || continue
    name=$(basename "$t" .sh)
    if [ "${AI_NATIVE_TESTS:-}" = 1 ]; then
        HOME="$REAL_HOME" bash "$t"; rc=$?
        case $rc in 0) echo "PASS $name";; 77) echo "NOT RUN $name (see reason above)";; *) echo "FAIL $name"; failed=1;; esac
    else
        echo "NOT RUN $name (native test; set AI_NATIVE_TESTS=1 with real CLIs)"
    fi
done
exit "$failed"
