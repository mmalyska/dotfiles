# Accepted `claude-plugins` revisions

Acceptance record for the revision of `mmalyska/claude-plugins` that `dotfiles` installs.
The workflow contract (lifecycle, profiles, topologies) lives in `claude-plugins`;
`dotfiles` only distributes it. Upgrade procedure: [upgrade-runbook.md](upgrade-runbook.md).

| Field | Value |
| --- | --- |
| Revision | `1a0724307063084cc05de58096032dee2c00490a` |
| Tag | `ai-workflow-v0.1.1` |
| Status | accepted by the owner; the remaining full-conformance release gates are not required |
| Accepted | 2026-11-08 |
| Specification | `docs/workflow/specification.md` in `mmalyska/claude-plugins` at the revision above |

## History

| Accepted | Revision | Tag | CLI versions | Test results |
| --- | --- | --- | --- | --- |
| 2026-11-08 | `1a0724307063084cc05de58096032dee2c00490a` | `ai-workflow-v0.1.1` | claude 2.1.316, codex 0.166.0, chezmoi 2.74.0 | `tests/ai/run.sh` PASS; with `AI_NATIVE_TESTS=1` PASS (e2e-native 17/17); Pester in CI only |
| 2026-10-30 | `25d785abee26ca7a3c87e8311f46e8a90f225301` | none recorded | see `evidence/T00-baseline.md` | see `evidence/T00-baseline.md` |

## Pinning

| Harness | Pin | Evidence |
| --- | --- | --- |
| Codex | native: `codex plugin marketplace add mmalyska/claude-plugins --ref <sha>`; idempotent | plan.md section 1.3 |
| Claude Code | SHA unsupported (`owner/repo#<sha>` fails: `Remote branch <sha> not found`); `pin_mode: verify` = lock in `home/.chezmoidata/ai-workflow.yaml` + drift check, no automatic `marketplace update` | plan.md section 1.3 |

Tag support in Claude Code (`owner/repo#tag`, `extraKnownMarketplaces.source.ref`) is decided by
spike S1 (plan T06). Until then `pin_mode` stays `verify`.
