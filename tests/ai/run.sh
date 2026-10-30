#!/usr/bin/env bash
# Runs tests/ai/test_*.sh, each with a private throw-away HOME.
# Native tests (tests/ai/e2e-*.sh) run only with AI_NATIVE_TESTS=1, otherwise NOT RUN.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
export AI_ROOT=$ROOT
REAL_HOME=${HOME:-}
failed=0
for t in "$ROOT"/tests/ai/test_*.sh; do
    name=$(basename "$t" .sh)
    tmp=$(mktemp -d)
    if HOME="$tmp" AI_REAL_HOME="$REAL_HOME" bash "$t"; then
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
