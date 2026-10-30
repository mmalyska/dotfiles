#!/usr/bin/env bash
# Native (opt-in, AI_NATIVE_TESTS=1): the real codex CLI against GitHub, in an isolated CODEX_HOME. Exit 77 = NOT RUN.
. "$(dirname "$0")/lib.sh"
command -v codex >/dev/null 2>&1 || { echo "  NOT RUN: no codex CLI on PATH"; exit 77; }
git ls-remote --exit-code https://github.com/mmalyska/claude-plugins.git HEAD >/dev/null 2>&1 || { echo "  NOT RUN: github.com not reachable"; exit 77; }

mkdir -p "$HOME/.cache"
CH=$(mktemp -d "$HOME/.cache/ai-workflow-test.XXXX")
trap 'rm -rf "$CH"' EXIT
export CODEX_HOME="$CH"
S="$CH/installer.sh"
chezmoi --source "$AI_ROOT" --config "$FIXTURES/core-linux.toml" execute-template \
    < "$AI_ROOT/home/.chezmoiscripts/ai/run_onchange_after_110-codex-plugins.sh.tmpl" > "$S"

STATE_HOME="$CH/state"
XDG_STATE_HOME="$STATE_HOME" bash "$S" || _fail "first run"
cfg="$CH/config.toml"
assert_contains "ref pinned" "$(cat "$cfg")" "ref = \"$SHA\""
assert_contains "plugin enabled" "$(cat "$cfg")" '[plugins."git-workflows@mmalyska-claude-plugins"]'
assert_contains "status" "$(cat "$STATE_HOME/ai-workflow/codex.status")" "result=ok"
cp "$cfg" "$CH/config.first"
XDG_STATE_HOME="$STATE_HOME" bash "$S" || _fail "second run"
diff "$CH/config.first" "$cfg" >/dev/null || _fail "second run changed config.toml"
