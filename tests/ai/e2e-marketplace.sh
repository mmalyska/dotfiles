#!/usr/bin/env bash
# Native (opt-in, AI_NATIVE_TESTS=1): plugins.own must equal marketplace.json at the accepted revision.
. "$(dirname "$0")/lib.sh"
command -v gh >/dev/null 2>&1 || _fail "gh not available"
sha=$(chezmoi --source "$AI_ROOT" --config "$FIXTURES/legacy-linux.toml" execute-template \
    '{{ .ai_workflow.marketplace.own.accepted_sha }}')
remote=$(gh api -H "Accept: application/vnd.github.raw" \
    "repos/mmalyska/claude-plugins/contents/.claude-plugin/marketplace.json?ref=$sha") \
    || _fail "cannot fetch marketplace.json at $sha"
data=$(chezmoi --source "$AI_ROOT" --config "$FIXTURES/legacy-linux.toml" data --format json)
printf '%s' "$data" | python3 -I -c '
import json, sys
local = set(json.load(sys.stdin)["ai_workflow"]["plugins"]["own"])
remote = {x["name"] for x in json.loads(sys.argv[1])["plugins"]}
assert local == remote, "plugins.own != marketplace.json: %s" % sorted(local ^ remote)
' "$remote" || _fail "plugins.own differs from marketplace.json at accepted revision"
