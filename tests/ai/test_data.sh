#!/usr/bin/env bash
# home/.chezmoidata/ai-workflow.yaml must load into templates and have the expected shape.
. "$(dirname "$0")/lib.sh"

for f in legacy-linux legacy-darwin legacy-windows legacy-devcontainer; do
    sha=$(chezmoi --source "$AI_ROOT" --config "$FIXTURES/$f.toml" execute-template \
        '{{ .ai_workflow.marketplace.own.accepted_sha }}') || _fail "$f: data not available in templates"
    assert_eq "accepted_sha ($f)" "$sha" 25d785abee26ca7a3c87e8311f46e8a90f225301
done

data=$(chezmoi --source "$AI_ROOT" --config "$FIXTURES/legacy-linux.toml" data --format json) \
    || _fail "chezmoi data failed"
printf '%s' "$data" | python3 -I -c '
import json, re, sys
d = json.load(sys.stdin)["ai_workflow"]
m, p, pr = d["marketplace"]["own"], d["plugins"], d["profiles"]
assert re.fullmatch(r"[0-9a-f]{40}", m["accepted_sha"]), "accepted_sha must be 40 hex"
assert m["accepted_tag"] in ("", "ai-workflow-v0.1.0-preview.1"), "unexpected accepted_tag"
assert m["pin_mode"] in ("verify", "tag"), "pin_mode"
assert len(p["own"]) == 12 and len(set(p["own"])) == 12, "own must be 12 unique"
assert len(p["workflow"]) == 2 and len(set(p["workflow"])) == 2, "workflow must be 2 unique"
assert len(p["claude_extras"]) == 4 and len(set(p["claude_extras"])) == 4, "extras must be 4 unique"
assert set(p["workflow"]) == {"git-workflows", "development-lifecycle"}, "workflow set"
assert set(p["workflow"]) <= set(p["own"]), "workflow must be a subset of own"
assert set(pr) == {"minimal", "core", "claude-extended"}, "profiles (no bare)"
for name, prof in pr.items():
    assert prof["own_set"] in p, name + ": own_set does not exist"
    assert isinstance(prof["extras"], bool), name + ": extras must be bool"
' || _fail "data shape"

# Malformed YAML must fail loudly instead of rendering an empty value.
t=$(new_tmp)
rsync -a --exclude .git --exclude .worktrees "$AI_ROOT/" "$t/src/"
printf 'ai_workflow: [\n' > "$t/src/home/.chezmoidata/ai-workflow.yaml"
if chezmoi --source "$t/src" --config "$FIXTURES/legacy-linux.toml" execute-template \
    '{{ .ai_workflow.plugins.own }}' >/dev/null 2>&1; then
    _fail "malformed YAML rendered successfully"
fi

# Plugin list must equal the marketplace at the accepted revision (needs gh + network).
if command -v gh >/dev/null 2>&1 && \
   remote=$(gh api -H "Accept: application/vnd.github.raw" \
       "repos/mmalyska/claude-plugins/contents/.claude-plugin/marketplace.json?ref=25d785abee26ca7a3c87e8311f46e8a90f225301" 2>/dev/null); then
    printf '%s' "$data" | python3 -I -c '
import json, sys
local = set(json.load(sys.stdin)["ai_workflow"]["plugins"]["own"])
remote = {x["name"] for x in json.loads(sys.argv[1])["plugins"]}
assert local == remote, "plugins.own != marketplace.json: %s" % sorted(local ^ remote)
' "$remote" || _fail "plugins.own differs from marketplace.json at accepted revision"
else
    echo "  NOT RUN: marketplace.json comparison (needs gh and network)" >&2
fi
