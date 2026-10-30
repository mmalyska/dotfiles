# Accepted `claude-plugins` revisions

Acceptance record for the revision of `mmalyska/claude-plugins` that `dotfiles` installs.
The workflow contract (lifecycle, profiles, topologies) lives in `claude-plugins`;
`dotfiles` only distributes it. Upgrade procedure: [upgrade-runbook.md](upgrade-runbook.md).

| Field | Value |
| --- | --- |
| Revision | `25d785abee26ca7a3c87e8311f46e8a90f225301` |
| Status | qualified preview; the remaining full-conformance release gates are not required |
| Accepted | 2026-10-30 |
| Specification | `docs/workflow/specification.md` in `mmalyska/claude-plugins` at the revision above |
| Planned tag | `ai-workflow-v0.1.0-preview.1` — **not created yet**; created only on explicit instruction, after spike S1 (plan T06) |
| Tools at acceptance | see `evidence/T00-baseline.md` |

## Pinning

| Harness | Pin | Evidence |
| --- | --- | --- |
| Codex | native: `codex plugin marketplace add mmalyska/claude-plugins --ref <sha>`; idempotent | plan.md section 1.3 |
| Claude Code | SHA unsupported (`owner/repo#<sha>` fails: `Remote branch <sha> not found`); `pin_mode: verify` = lock in `home/.chezmoidata/ai-workflow.yaml` + drift check, no automatic `marketplace update` | plan.md section 1.3 |

Tag support in Claude Code (`owner/repo#tag`, `extraKnownMarketplaces.source.ref`) is decided by
spike S1 (plan T06). Until then `pin_mode` stays `verify`.
