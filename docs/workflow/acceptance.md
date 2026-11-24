# Accepted `claude-plugins` revisions

Acceptance record for the revision of `mmalyska/claude-plugins` that `dotfiles` installs.
The workflow contract (lifecycle, profiles, topologies) lives in `claude-plugins`;
`dotfiles` only distributes it. Upgrade procedure: [upgrade-runbook.md](upgrade-runbook.md).

The accepted revision and its tag are in `home/.chezmoidata/ai-workflow.yaml` (`accepted_sha`, `accepted_tag`) and nowhere
else, so a pin change is one reviewed edit. Renovate opens it as a pull request when `claude-plugins` has a newer
`ai-workflow-v*` tag (`.github/renovate.json5`); **merging that pull request is the acceptance**. The git history of the data
file is the acceptance log. The specification of the accepted revision is `docs/workflow/specification.md` in
`mmalyska/claude-plugins` at that revision.

## History

Rows below are written by hand when a revision was also tried with the native CLIs (upgrade runbook, step 2); a revision
accepted through its pull request alone has no row.

| Accepted | Revision | Tag | CLI versions | Test results |
| --- | --- | --- | --- | --- |
| 2026-11-24 | `d17cc25f567caae3cc5eb7afbbc1c4da93e450f1` | `ai-workflow-v0.1.3` | claude 2.1.325, codex 0.166.0, chezmoi 2.74.1 | `tests/ai/run.sh`: every test PASS except `test_backup` and `test_workflow_pins`, which fail the same way on a clean `main` and are not touched by this change; `AI_NATIVE_TESTS=1` NOT RUN (the change is a worktree-guard fix, claude-plugins#44: `git-workflows` 1.3.12); Pester in CI only |
| 2026-11-08 | `4075ee1488b11214421dffc1ec8c9351193f6ff9` | `ai-workflow-v0.1.2` | claude 2.1.316, codex 0.166.0, chezmoi 2.74.0 | `tests/ai/run.sh` PASS; with `AI_NATIVE_TESTS=1` PASS (e2e-native 17/17); Pester in CI only |
| 2026-11-08 | `1a0724307063084cc05de58096032dee2c00490a` | `ai-workflow-v0.1.1` | claude 2.1.316, codex 0.166.0, chezmoi 2.74.0 | `tests/ai/run.sh` PASS; with `AI_NATIVE_TESTS=1` PASS (e2e-native 17/17); Pester in CI only |
| 2026-10-30 | `25d785abee26ca7a3c87e8311f46e8a90f225301` | none recorded | see `evidence/T00-baseline.md` | see `evidence/T00-baseline.md` |

## Pinning

| Harness | Pin | Evidence |
| --- | --- | --- |
| Codex | native: `codex plugin marketplace add mmalyska/claude-plugins --ref <sha>`; idempotent | plan.md section 1.3 |
| Claude Code | SHA unsupported (`owner/repo#<sha>` fails: `Remote branch <sha> not found`); `pin_mode: verify` = lock in `home/.chezmoidata/ai-workflow.yaml` + drift check, no automatic `marketplace update` | plan.md section 1.3 |

Tag support in Claude Code (`owner/repo#tag`, `extraKnownMarketplaces.source.ref`) is decided by
spike S1 (plan T06). Until then `pin_mode` stays `verify`.
