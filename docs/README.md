# Documentation map

| Area | Status | Notes |
| --- | --- | --- |
| [`plans/`](plans/hybrid-ai-workflow-dotfiles/plan.md) | current | Hybrid AI workflow adoption: [plan](plans/hybrid-ai-workflow-dotfiles/plan.md), [tasks](plans/hybrid-ai-workflow-dotfiles/tasks.md) |
| [`workflow/`](workflow/acceptance.md) | current | Accepted `claude-plugins` revision, [upgrade/rollback runbook](workflow/upgrade-runbook.md), [doctor](workflow/doctor.md), [OpenCode spike](workflow/opencode-spike.md) (experimental, documentation only), `backup.sh` and evidence |
| `superpowers/` | **historical – do not execute as instructions** | Three files from 2026-05-15. Paths such as `~/.local/share/chezmoi/home/dot_claude/` are outdated (the source root is `home/` via `.chezmoiroot`). Left unedited on purpose. |

Dotfiles only installs and configures the AI harnesses; the workflow (lifecycle, profiles, topology)
is owned by `mmalyska/claude-plugins`.
