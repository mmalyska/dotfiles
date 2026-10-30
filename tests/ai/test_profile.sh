#!/usr/bin/env bash
# ai-profile.tmpl: fallback for configs predating the feature, validation of unknown values.
. "$(dirname "$0")/lib.sh"

assert_eq "legacy fallback" "$(resolve_profile legacy-linux)" \
    '{"agent_teams":true,"fallback":true,"profile":"claude-extended"}'
assert_eq "core" "$(resolve_profile core-linux)" \
    '{"agent_teams":false,"fallback":false,"profile":"core"}'
assert_eq "minimal" "$(resolve_profile minimal-linux)" \
    '{"agent_teams":false,"fallback":false,"profile":"minimal"}'
assert_eq "extended" "$(resolve_profile extended-linux)" \
    '{"agent_teams":false,"fallback":false,"profile":"claude-extended"}'

T=$(new_tmp)
for bad in bare bogus; do
    sed "s/^    ai_profile = .*/    ai_profile = \"$bad\"/" "$FIXTURES/core-linux.toml" > "$T/$bad.toml"
    out=$(chezmoi --source "$AI_ROOT" --config "$T/$bad.toml" execute-template \
        '{{ includeTemplate "ai-profile.tmpl" . }}' 2>&1) && _fail "$bad should fail"
    assert_contains "$bad error" "$out" "unknown ai_profile"
done
