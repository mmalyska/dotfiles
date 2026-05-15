# Claude Personal Marketplace Design

**Date:** 2026-05-15
**Status:** Approved

## Overview

A public GitHub marketplace repo (`mmalyska/claude-plugins`) that houses all personal Claude Code artifacts — agents, commands, rules, and skills — currently scattered across chezmoi dotfiles. The marketplace follows the `claude-plugins-official` format, organized as separate domain plugins plus a meta-bundle for one-command installation.

---

## Section 1: Repo & Marketplace Structure

```
claude-plugins/
├── plugins/
│   ├── git-workflows/
│   ├── renovate/
│   ├── devcontainer/
│   ├── development-lifecycle/
│   ├── dotnet/
│   ├── android/
│   ├── frontend/
│   └── personal-essentials/    ← meta-plugin, depends on all above
├── README.md
└── manifest.yaml               ← marketplace index listing all plugins
```

Each plugin follows the standard structure:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json    ← name, description, version, author, keywords
├── agents/            ← .md agent definitions (if any)
├── commands/          ← .md slash commands (if any)
├── rules/             ← .md rule files (if any)
├── skills/            ← .md skill files (if any)
└── README.md
```

**Installation:**
```sh
/plugin add marketplace github:mmalyska/claude-plugins
/plugin install personal-essentials@mmalyska/claude-plugins
```

---

## Section 2: Plugin Breakdown & Content Mapping

### `git-workflows`
- **Commands:** `prp-pr`, `prp-commit` (migrated from chezmoi)
- **Rules:** `common/git-workflow.md`, `common/development-workflow.md` (migrated from chezmoi)
- **Skills:** reusable workflow authoring patterns (`uses: mmalyska/github-workflows/...@main`), PR label automation (meta-enforce-labels / size-labeler / sync-labels patterns from home-ops), MegaLinter integration
- **Agent:** workflow auditor — checks `.github/workflows/` for consistency with reusable workflow conventions

### `renovate`
- **Skills:** extending `mmalyska/renovate-config` preset, custom regex manager authoring (YAML/Dockerfile/DevContainer patterns from `generic-regex-manager.json5` and `devcontainer-regex-manager.json5`), datasource-specific automerge rules (Docker digests / GH Actions / Terraform / Ansible)
- **Agent:** Renovate config auditor — checks a repo's `renovate.json` for consistency with the shared preset conventions

### `devcontainer`
- **Skills:** custom image build + GHCR publish pipeline (devcontainers/ci action pattern from home-ops), secrets injection via `devcontainer.env` (Bitwarden Secrets / WireGuard / Terraform patterns), Renovate integration for image digest pinning (references `renovate` plugin)
- **Agent:** devcontainer config auditor — checks for unpinned images, missing secrets declarations, lifecycle hook coverage

### `development-lifecycle`
Fork of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) 7-stage model, adapted to existing `prp-*` command conventions.

| Command | Stage | Sources & Adaptations |
|---|---|---|
| `/spec` | Define problem, write PRD | Replaces `prp-prd` — interactive problem-first spec |
| `/plan` | Task decomposition | Replaces `prp-plan` — phases + acceptance criteria per task |
| `/build` | Implementation | Replaces `prp-implement` — TDD loop, calls `tdd-guide` agent |
| `/test` | Verification | New — runs tests, 80% coverage gate, calls `build-error-resolver` |
| `/review` | Code review | Replaces `code-review` — calls `code-reviewer` + domain agents contextually |
| `/simplify` | Refactor & clean | Replaces `aside` — calls `code-simplifier`, enforces immutability rules |
| `/ship` | Commit + PR | Replaces `prp-pr` + `prp-commit` — conventional commit, PR with template |

Each command embeds a **verification gate** — it will not advance until the current stage's criteria are met (`/build` requires tests exist; `/review` blocks on CRITICAL issues).

**Flow:** `/spec` → `/plan` → loop(`/build` → `/test` → `/review` → `/simplify`) → `/ship`

**Agents (migrated from chezmoi):** `planner`, `architect`, `tdd-guide`, `code-reviewer`, `build-error-resolver`, `doc-updater`, `docs-lookup`

**Rules (migrated from chezmoi):** `common/coding-style`, `testing`, `performance`, `patterns`, `hooks`, `security`, `code-review`, `agents`

### `dotnet`
- **Agents:** `csharp-reviewer`, `database-reviewer` (migrated from chezmoi)
- **Rules:** solution layout (`src/` + `test/`), `Directory.Build.props` shared settings, xUnit + coverlet + Moq patterns, `.editorconfig` C# style conventions, multi-platform CI (Ubuntu/Windows/macOS), cosign-signed GHCR publishing
- **Target:** .NET 10 (latest SDK)

### `android`
- New content — to be developed

### `frontend`
- **Rules:** entire `web/` ruleset from chezmoi (coding-style, testing, performance, patterns, hooks, design-quality, security)
- **Target:** React / Next.js

### `personal-essentials`
- No files of its own
- `plugin.json` declares all seven plugins above as dependencies

---

## Section 3: Migration from Chezmoi

### What leaves chezmoi
- `home/dot_claude/agents/` — all agent `.md` files
- `home/dot_claude/commands/` — all command `.md` files
- `home/dot_claude/rules/` — all rule files (`web/*` and `common/*`)
- `home/dot_claude/skills/claude-devfleet` — the one custom skill

### What stays in chezmoi
- `home/dot_claude/settings.json.tmpl` — machine-specific settings (hooks, MCP config, model prefs)
- `home/dot_claude/statusline/` — statusline config

### What chezmoi gains
A `run_once_install-claude-plugins.sh` bootstrap script:
```sh
claude plugin add marketplace github:mmalyska/claude-plugins
claude plugin install personal-essentials@mmalyska/claude-plugins
```

### Migration order
1. Create the repo and populate all plugins
2. Register the marketplace and install `personal-essentials` on current machine — verify everything works
3. Only then remove the migrated files from chezmoi and commit
