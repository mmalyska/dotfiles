#!/usr/bin/env bash
# The pin lives only in the data file (Renovate edits it there); the acceptance record must not repeat it or hold a placeholder.
. "$(dirname "$0")/lib.sh"

RECORD=$(cat "$AI_ROOT/docs/workflow/acceptance.md")
case $RECORD in *'%s'*) _fail "acceptance.md has an unfilled %s placeholder";; esac
assert_contains "points at the data file" "$RECORD" "home/.chezmoidata/ai-workflow.yaml"
printf '%s\n' "$RECORD" | grep -q '^| Revision |' && _fail "acceptance.md repeats the pin; Renovate cannot keep it in step"
# every revision in the history is a full SHA
# shellcheck disable=SC2016 # the backticks are literal
while IFS= read -r sha; do
    [[ $sha =~ ^[0-9a-f]{40}$ ]] || _fail "history row without a full sha: $sha"
done < <(printf '%s\n' "$RECORD" | sed -n 's/^| [0-9-]* | `\([^`]*\)`.*/\1/p' | grep -v '^$')
# the data file is what Renovate edits: both pin lines exist, each once, and are adjacent
DATA=$AI_ROOT/home/.chezmoidata/ai-workflow.yaml
assert_eq "accepted_sha lines" "$(grep -c '^ *accepted_sha: [0-9a-f]\{40\}$' "$DATA")" "1"
assert_eq "accepted_tag lines" "$(grep -c '^ *accepted_tag: ai-workflow-v[0-9.]*$' "$DATA")" "1"
awk '/accepted_sha:/{f=1;next} f{ok=/accepted_tag:/; exit} END{exit !(f && ok)}' "$DATA" \
    || _fail "accepted_tag must be the line right after accepted_sha: Renovate rewrites exactly those two lines and would delete anything between them"
:
