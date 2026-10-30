#!/usr/bin/env bash
# settings.json.tmpl is profile-driven; legacy hosts keep the previous render.
. "$(dirname "$0")/lib.sh"

S=home/dot_claude/settings.json.tmpl
T=$(new_tmp)
for f in minimal core extended extended-teams legacy-linux; do
    n=${f%-linux}; case $n in minimal|core|extended|extended-teams) fx=$n-linux;; *) fx=$f;; esac
    render "$fx" $S > "$T/$n.json" || _fail "$fx: render failed"
    python3 -I -m json.tool "$T/$n.json" >/dev/null || _fail "$n: invalid JSON"
done

count() { python3 -I -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["enabledPlugins"]))' "$1"; }
has() { python3 -I -c 'import json,sys;d=json.load(open(sys.argv[1]));k=sys.argv[2:]
for p in k[:-1]:
    d=d.get(p,{}) if isinstance(d,dict) else {}
print("yes" if k[-1] in d else "no")' "$@"; }

# goldens
for n in minimal core extended; do
    assert_eq "$n golden" "$(sorted_json < "$T/$n.json")" "$(sorted_json < "$GOLDEN/$n.settings.json")"
done

# sizes and contents
assert_eq "minimal plugin count" "$(count "$T/minimal.json")" 2
assert_eq "core plugin count" "$(count "$T/core.json")" 12
assert_eq "extended plugin count" "$(count "$T/extended.json")" 16
assert_eq "minimal has git-workflows" "$(has "$T/minimal.json" enabledPlugins git-workflows@mmalyska-claude-plugins)" yes
assert_eq "minimal has development-lifecycle" "$(has "$T/minimal.json" enabledPlugins development-lifecycle@mmalyska-claude-plugins)" yes
assert_eq "core lacks superpowers" "$(has "$T/core.json" enabledPlugins superpowers@claude-plugins-official)" no
assert_eq "extended has superpowers" "$(has "$T/extended.json" enabledPlugins superpowers@claude-plugins-official)" yes

# marketplaces: official only with extras; no pinning ref in settings
for n in minimal core; do
    assert_eq "$n no official marketplace" "$(has "$T/$n.json" extraKnownMarketplaces claude-plugins-official)" no
done
assert_eq "extended official marketplace" "$(has "$T/extended.json" extraKnownMarketplaces claude-plugins-official)" yes
for n in minimal core extended; do
    assert_eq "$n own marketplace" "$(has "$T/$n.json" extraKnownMarketplaces mmalyska-claude-plugins)" yes
    assert_not_contains "$n no ref" "$(cat "$T/$n.json")" '"ref"'
done
own_repo=$(awk '/own:/{f=1} f&&/repo:/{print $2; exit}' "$AI_ROOT/home/.chezmoidata/ai-workflow.yaml")
assert_contains "own repo from data" "$(cat "$T/core.json")" "\"repo\": \"$own_repo\""

# agent teams only when requested (or legacy fallback)
for n in minimal core extended; do
    assert_not_contains "$n no agent teams" "$(cat "$T/$n.json")" AGENT_TEAMS
done
assert_contains "extended+teams" "$(cat "$T/extended-teams.json")" CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
assert_contains "legacy teams" "$(cat "$T/legacy.json")" CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

# workflow concepts belong to claude-plugins, never to dotfiles configs
for n in minimal core extended; do
    if grep -Eq 'STANDARD|SOLO|Spec|profile|topology|lifecycle' "$T/$n.json"; then
        grep -En 'STANDARD|SOLO|Spec|profile|topology|lifecycle' "$T/$n.json" | grep -v 'development-lifecycle@' | grep -q . \
            && _fail "$n: workflow concept leaked into settings"
    fi
done

# no secrets
for n in minimal core extended; do
    ! grep -Eqi 'ghp_|github_pat_|sk-[a-z0-9]{10}|api[_-]?key|password' "$T/$n.json" || _fail "$n: secret-like string"
done

# everything outside env/enabledPlugins/extraKnownMarketplaces is identical across profiles
strip() { python3 -I -c 'import json,sys;d=json.load(open(sys.argv[1]))
for k in ("env","enabledPlugins","extraKnownMarketplaces"): d.pop(k,None)
print(json.dumps(d,sort_keys=True))' "$1"; }
assert_eq "common sections minimal/core" "$(strip "$T/minimal.json")" "$(strip "$T/core.json")"
assert_eq "common sections core/extended" "$(strip "$T/core.json")" "$(strip "$T/extended.json")"
assert_eq "common sections legacy/core" "$(strip "$T/legacy.json")" "$(strip "$T/core.json")"
