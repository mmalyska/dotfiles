#!/usr/bin/env bash
# T11b: the runbook keeps its promises (steps, exact prompt texts, the printed recovery shape, the prohibition) and the
# historical docs/superpowers stay untouched.
. "$(dirname "$0")/lib.sh"

R=$(cat "$AI_ROOT/docs/workflow/upgrade-runbook.md")
for h in "## 0. Choosing a profile" "## 1. Backup" "## 2. Try the new revision" "## 3. Pull request" "## 4. Apply the upgrade" \
         "## 5. Verify" "### Recovery after a partial install" "## 6. Rollback" "## 7. Changing the profile"; do
    assert_contains "section: $h" "$R" "$h"
done
# prompt texts quoted in the runbook are the ones in .chezmoi.toml.tmpl (R12)
for p in "$PROMPT_PROFILE" "$PROMPT_TEAMS" "$PROMPT_CLAUDE" "$PROMPT_CODEX"; do assert_contains "prompt [$p]" "$R" "$p="; done
assert_contains "promptDefaults" "$R" "chezmoi init --promptDefaults"
assert_contains "AI_WORKFLOW_UPGRADE" "$R" "AI_WORKFLOW_UPGRADE=1 chezmoi apply"
assert_contains "backup.sh" "$R" "docs/workflow/backup.sh"
assert_contains "accepted_sha rollback" "$R" "accepted_sha"
assert_contains "recovery sequence" "$R" "failure -> ai-workflow-doctor --strict -> chezmoi state delete --bucket=entryState --key=<printed key> -> chezmoi apply -> ai-workflow-doctor --strict"
assert_contains "codex remove+add" "$R" "codex plugin marketplace remove mmalyska-claude-plugins"
assert_contains "single key" "$R" "Reset a single key only"
# every runbook command that resets state targets one entryState key
while IFS= read -r line; do
    case "$line" in *"state delete --bucket=entryState --key="*) ;; *"state delete --"*) case "$line" in *"entryState --key=<printed key>"*) ;; *) _fail "state delete without a single entryState key: $line";; esac;; esac
done < <(printf '%s\n' "$R")
# the backup script named in the runbook exists and is the documented one
[ -f "$AI_ROOT/docs/workflow/backup.sh" ] || _fail "docs/workflow/backup.sh missing"
for f in settings.json config.toml claude-plugins.json codex-plugins.txt; do assert_contains "backup file $f" "$R" "\`$f\`"; done

# the historical Superpowers documents are untouched and still referenced as historical
[ -z "$(git -C "$AI_ROOT" status --porcelain -- docs/superpowers 2>/dev/null)" ] || _fail "docs/superpowers has local changes"
assert_eq "docs/superpowers files" "$(find "$AI_ROOT/docs/superpowers" -type f | wc -l | tr -d ' ')" "3"
assert_eq "docs/README mentions superpowers once as historical" "$(grep -c 'docs/superpowers\|superpowers/' "$AI_ROOT/docs/README.md")" "1"
