# Claude Marketplace Scaffold & Content Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a public GitHub repo `mmalyska/claude-plugins` as a Claude Code marketplace, populate it with all existing agents/commands/rules/skills from chezmoi dotfiles, and verify it installs cleanly on the current machine.

**Architecture:** Eight plugins under `plugins/` each with `.claude-plugin/plugin.json`. Content is copied from `~/.local/share/chezmoi/home/dot_claude/` into the appropriate plugin directory. A `personal-essentials` plugin provides a `/personal-setup` command that installs all other plugins. No manifest.yaml is needed — Claude Code discovers plugins by scanning `plugins/*/` for `.claude-plugin/plugin.json`.

**Tech Stack:** GitHub (gh CLI), Claude Code plugin system, JSON (plugin.json), Markdown (agents/commands/rules/skills)

---

## File Map

```
claude-plugins/
├── plugins/
│   ├── git-workflows/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── commands/prp-pr.md
│   │   ├── commands/prp-commit.md
│   │   ├── rules/git-workflow.md
│   │   ├── rules/development-workflow.md
│   │   └── README.md
│   ├── development-lifecycle/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/architect.md
│   │   ├── agents/build-error-resolver.md
│   │   ├── agents/code-reviewer.md
│   │   ├── agents/doc-updater.md
│   │   ├── agents/docs-lookup.md
│   │   ├── agents/planner.md
│   │   ├── agents/tdd-guide.md
│   │   ├── commands/aside.md
│   │   ├── commands/code-review.md
│   │   ├── commands/learn-eval.md
│   │   ├── commands/plan.md
│   │   ├── commands/prp-implement.md
│   │   ├── commands/prp-plan.md
│   │   ├── commands/prp-prd.md
│   │   ├── commands/skill-create.md
│   │   ├── commands/update-codemaps.md
│   │   ├── commands/update-docs.md
│   │   ├── rules/common/agents.md
│   │   ├── rules/common/code-review.md
│   │   ├── rules/common/coding-style.md
│   │   ├── rules/common/hooks.md
│   │   ├── rules/common/patterns.md
│   │   ├── rules/common/performance.md
│   │   ├── rules/common/security.md
│   │   ├── rules/common/testing.md
│   │   ├── skills/claude-devfleet/SKILL.md
│   │   └── README.md
│   ├── dotnet/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/csharp-reviewer.md
│   │   ├── agents/database-reviewer.md
│   │   ├── rules/csharp/coding-style.md
│   │   ├── rules/csharp/hooks.md
│   │   ├── rules/csharp/patterns.md
│   │   ├── rules/csharp/security.md
│   │   ├── rules/csharp/testing.md
│   │   └── README.md
│   ├── frontend/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── rules/web/coding-style.md
│   │   ├── rules/web/design-quality.md
│   │   ├── rules/web/hooks.md
│   │   ├── rules/web/patterns.md
│   │   ├── rules/web/performance.md
│   │   ├── rules/web/security.md
│   │   ├── rules/web/testing.md
│   │   ├── rules/typescript/coding-style.md
│   │   ├── rules/typescript/hooks.md
│   │   ├── rules/typescript/patterns.md
│   │   ├── rules/typescript/security.md
│   │   ├── rules/typescript/testing.md
│   │   └── README.md
│   ├── renovate/
│   │   ├── .claude-plugin/plugin.json
│   │   └── README.md
│   ├── devcontainer/
│   │   ├── .claude-plugin/plugin.json
│   │   └── README.md
│   ├── android/
│   │   ├── .claude-plugin/plugin.json
│   │   └── README.md
│   └── personal-essentials/
│       ├── .claude-plugin/plugin.json
│       ├── commands/personal-setup.md
│       └── README.md
└── README.md
```

---

### Task 1: Create GitHub repo and clone locally

**Files:**
- Create: `claude-plugins/` (local directory, becomes git repo)

- [ ] **Step 1: Create public GitHub repo**

```bash
gh repo create mmalyska/claude-plugins \
  --public \
  --description "Personal Claude Code plugin marketplace — agents, commands, rules, and skills" \
  --clone
cd claude-plugins
```

Expected: directory `claude-plugins/` created, `.git/` initialized, remote `origin` pointing to `github.com/mmalyska/claude-plugins`.

- [ ] **Step 2: Create top-level README and initial commit**

Create `README.md`:
```markdown
# mmalyska/claude-plugins

Personal Claude Code plugin marketplace.

## Install

```sh
claude plugin add marketplace github:mmalyska/claude-plugins
claude plugin install personal-essentials@mmalyska/claude-plugins
```

## Plugins

| Plugin | Description |
|---|---|
| `git-workflows` | Git discipline, PR creation, commit conventions |
| `development-lifecycle` | Spec→Plan→Build→Test→Review→Simplify→Ship workflow |
| `dotnet` | .NET/C# agents and coding rules |
| `frontend` | React/Next.js and TypeScript rules |
| `renovate` | Renovate config authoring skills |
| `devcontainer` | Dev container setup skills |
| `android` | Android development (coming soon) |
| `personal-essentials` | Installs all plugins above |
```

```bash
git add README.md
git commit -m "chore: init repository"
git push -u origin main
```

---

### Task 2: Scaffold all plugin directories and plugin.json files

**Files:**
- Create: `plugins/git-workflows/.claude-plugin/plugin.json`
- Create: `plugins/development-lifecycle/.claude-plugin/plugin.json`
- Create: `plugins/dotnet/.claude-plugin/plugin.json`
- Create: `plugins/frontend/.claude-plugin/plugin.json`
- Create: `plugins/renovate/.claude-plugin/plugin.json`
- Create: `plugins/devcontainer/.claude-plugin/plugin.json`
- Create: `plugins/android/.claude-plugin/plugin.json`
- Create: `plugins/personal-essentials/.claude-plugin/plugin.json`

- [ ] **Step 1: Create all plugin.json files**

`plugins/git-workflows/.claude-plugin/plugin.json`:
```json
{
  "name": "git-workflows",
  "description": "Git discipline and automation — PR creation, commit conventions, reusable workflow patterns, MegaLinter integration",
  "version": "1.0.0",
  "author": {
    "name": "Michał Małyska"
  },
  "homepage": "https://github.com/mmalyska/claude-plugins",
  "repository": "https://github.com/mmalyska/claude-plugins",
  "license": "MIT",
  "keywords": ["git", "github", "pull-request", "commit", "workflows", "megalinter"]
}
```

`plugins/development-lifecycle/.claude-plugin/plugin.json`:
```json
{
  "name": "development-lifecycle",
  "description": "Full development lifecycle — agents, commands, and rules for Spec→Plan→Build→Test→Review→Simplify→Ship",
  "version": "1.0.0",
  "author": {
    "name": "Michał Małyska"
  },
  "homepage": "https://github.com/mmalyska/claude-plugins",
  "repository": "https://github.com/mmalyska/claude-plugins",
  "license": "MIT",
  "keywords": ["tdd", "planning", "code-review", "agents", "workflow", "lifecycle"]
}
```

`plugins/dotnet/.claude-plugin/plugin.json`:
```json
{
  "name": "dotnet",
  "description": ".NET/C# development — code reviewer agent, database reviewer, and C# coding rules",
  "version": "1.0.0",
  "author": {
    "name": "Michał Małyska"
  },
  "homepage": "https://github.com/mmalyska/claude-plugins",
  "repository": "https://github.com/mmalyska/claude-plugins",
  "license": "MIT",
  "keywords": ["dotnet", "csharp", "backend", "xunit", "asp-net"]
}
```

`plugins/frontend/.claude-plugin/plugin.json`:
```json
{
  "name": "frontend",
  "description": "React/Next.js and TypeScript frontend — coding style, testing, performance, design quality, and security rules",
  "version": "1.0.0",
  "author": {
    "name": "Michał Małyska"
  },
  "homepage": "https://github.com/mmalyska/claude-plugins",
  "repository": "https://github.com/mmalyska/claude-plugins",
  "license": "MIT",
  "keywords": ["react", "nextjs", "typescript", "frontend", "web", "css"]
}
```

`plugins/renovate/.claude-plugin/plugin.json`:
```json
{
  "name": "renovate",
  "description": "Renovate config authoring — extend mmalyska/renovate-config presets, custom regex managers, datasource-specific automerge",
  "version": "0.1.0",
  "author": {
    "name": "Michał Małyska"
  },
  "homepage": "https://github.com/mmalyska/claude-plugins",
  "repository": "https://github.com/mmalyska/claude-plugins",
  "license": "MIT",
  "keywords": ["renovate", "dependencies", "automation", "docker", "helm", "terraform"]
}
```

`plugins/devcontainer/.claude-plugin/plugin.json`:
```json
{
  "name": "devcontainer",
  "description": "Dev container setup — custom GHCR image pipelines, secrets injection, Renovate integration for digest pinning",
  "version": "0.1.0",
  "author": {
    "name": "Michał Małyska"
  },
  "homepage": "https://github.com/mmalyska/claude-plugins",
  "repository": "https://github.com/mmalyska/claude-plugins",
  "license": "MIT",
  "keywords": ["devcontainer", "docker", "ghcr", "development-environment"]
}
```

`plugins/android/.claude-plugin/plugin.json`:
```json
{
  "name": "android",
  "description": "Android mobile development — agents, rules, and patterns (coming soon)",
  "version": "0.1.0",
  "author": {
    "name": "Michał Małyska"
  },
  "homepage": "https://github.com/mmalyska/claude-plugins",
  "repository": "https://github.com/mmalyska/claude-plugins",
  "license": "MIT",
  "keywords": ["android", "kotlin", "mobile"]
}
```

`plugins/personal-essentials/.claude-plugin/plugin.json`:
```json
{
  "name": "personal-essentials",
  "description": "Meta-plugin — installs all mmalyska/claude-plugins at once via /personal-setup",
  "version": "1.0.0",
  "author": {
    "name": "Michał Małyska"
  },
  "homepage": "https://github.com/mmalyska/claude-plugins",
  "repository": "https://github.com/mmalyska/claude-plugins",
  "license": "MIT",
  "keywords": ["meta", "setup", "bootstrap"]
}
```

- [ ] **Step 2: Validate all plugin.json files are valid JSON**

```bash
find plugins -name "plugin.json" | xargs -I{} sh -c 'echo "Checking {}..." && jq empty {} && echo "OK"'
```

Expected: `OK` printed for each of the 8 files, no errors.

- [ ] **Step 3: Commit plugin scaffolds**

```bash
git add plugins/
git commit -m "chore: scaffold all plugin directories with plugin.json"
```

---

### Task 3: Populate git-workflows plugin

**Files:**
- Create: `plugins/git-workflows/commands/prp-pr.md` (copy from chezmoi)
- Create: `plugins/git-workflows/commands/prp-commit.md` (copy from chezmoi)
- Create: `plugins/git-workflows/rules/git-workflow.md` (copy from chezmoi)
- Create: `plugins/git-workflows/rules/development-workflow.md` (copy from chezmoi)
- Create: `plugins/git-workflows/README.md`

- [ ] **Step 1: Copy command and rule files**

```bash
CHEZMOI=~/.local/share/chezmoi/home/dot_claude
mkdir -p plugins/git-workflows/commands plugins/git-workflows/rules

cp "$CHEZMOI/commands/prp-pr.md"              plugins/git-workflows/commands/
cp "$CHEZMOI/commands/prp-commit.md"          plugins/git-workflows/commands/
cp "$CHEZMOI/rules/common/git-workflow.md"    plugins/git-workflows/rules/
cp "$CHEZMOI/rules/common/development-workflow.md" plugins/git-workflows/rules/
```

- [ ] **Step 2: Create README**

`plugins/git-workflows/README.md`:
```markdown
# git-workflows

Git discipline and automation for Claude Code.

## Commands

- `/prp-pr` — Create a GitHub PR from current branch with unpushed commits
- `/prp-commit` — Quick commit with natural language file targeting

## Rules

- `git-workflow.md` — Commit message format, PR workflow
- `development-workflow.md` — Full feature development pipeline (research → plan → TDD → review → commit)

## Install

```sh
claude plugin install git-workflows@mmalyska/claude-plugins
```
```

- [ ] **Step 3: Verify files copied correctly**

```bash
ls -la plugins/git-workflows/commands/ plugins/git-workflows/rules/
```

Expected: 2 files in commands/, 2 files in rules/.

- [ ] **Step 4: Commit**

```bash
git add plugins/git-workflows/
git commit -m "feat: populate git-workflows plugin"
```

---

### Task 4: Populate development-lifecycle plugin

**Files:**
- Create: `plugins/development-lifecycle/agents/` (7 agent files)
- Create: `plugins/development-lifecycle/commands/` (10 command files)
- Create: `plugins/development-lifecycle/rules/common/` (8 rule files)
- Create: `plugins/development-lifecycle/skills/claude-devfleet/SKILL.md`
- Create: `plugins/development-lifecycle/README.md`

- [ ] **Step 1: Copy agents**

```bash
CHEZMOI=~/.local/share/chezmoi/home/dot_claude
mkdir -p plugins/development-lifecycle/agents

cp "$CHEZMOI/agents/architect.md"            plugins/development-lifecycle/agents/
cp "$CHEZMOI/agents/build-error-resolver.md" plugins/development-lifecycle/agents/
cp "$CHEZMOI/agents/code-reviewer.md"        plugins/development-lifecycle/agents/
cp "$CHEZMOI/agents/doc-updater.md"          plugins/development-lifecycle/agents/
cp "$CHEZMOI/agents/docs-lookup.md"          plugins/development-lifecycle/agents/
cp "$CHEZMOI/agents/planner.md"              plugins/development-lifecycle/agents/
cp "$CHEZMOI/agents/tdd-guide.md"            plugins/development-lifecycle/agents/
```

- [ ] **Step 2: Copy commands**

```bash
mkdir -p plugins/development-lifecycle/commands

cp "$CHEZMOI/commands/aside.md"           plugins/development-lifecycle/commands/
cp "$CHEZMOI/commands/code-review.md"     plugins/development-lifecycle/commands/
cp "$CHEZMOI/commands/learn-eval.md"      plugins/development-lifecycle/commands/
cp "$CHEZMOI/commands/plan.md"            plugins/development-lifecycle/commands/
cp "$CHEZMOI/commands/prp-implement.md"   plugins/development-lifecycle/commands/
cp "$CHEZMOI/commands/prp-plan.md"        plugins/development-lifecycle/commands/
cp "$CHEZMOI/commands/prp-prd.md"         plugins/development-lifecycle/commands/
cp "$CHEZMOI/commands/skill-create.md"    plugins/development-lifecycle/commands/
cp "$CHEZMOI/commands/update-codemaps.md" plugins/development-lifecycle/commands/
cp "$CHEZMOI/commands/update-docs.md"     plugins/development-lifecycle/commands/
```

- [ ] **Step 3: Copy rules**

```bash
mkdir -p plugins/development-lifecycle/rules/common

cp "$CHEZMOI/rules/common/agents.md"       plugins/development-lifecycle/rules/common/
cp "$CHEZMOI/rules/common/code-review.md"  plugins/development-lifecycle/rules/common/
cp "$CHEZMOI/rules/common/coding-style.md" plugins/development-lifecycle/rules/common/
cp "$CHEZMOI/rules/common/hooks.md"        plugins/development-lifecycle/rules/common/
cp "$CHEZMOI/rules/common/patterns.md"     plugins/development-lifecycle/rules/common/
cp "$CHEZMOI/rules/common/performance.md"  plugins/development-lifecycle/rules/common/
cp "$CHEZMOI/rules/common/security.md"     plugins/development-lifecycle/rules/common/
cp "$CHEZMOI/rules/common/testing.md"      plugins/development-lifecycle/rules/common/
```

- [ ] **Step 4: Copy claude-devfleet skill**

```bash
mkdir -p plugins/development-lifecycle/skills/claude-devfleet

cp "$CHEZMOI/skills/claude-devfleet/SKILL.md" \
   plugins/development-lifecycle/skills/claude-devfleet/
```

- [ ] **Step 5: Create README**

`plugins/development-lifecycle/README.md`:
```markdown
# development-lifecycle

Full development lifecycle agents, commands, and rules for Claude Code.

## Agents

- `architect` — System design and architectural decisions
- `build-error-resolver` — Fix build/type errors
- `code-reviewer` — Code quality, security, maintainability
- `doc-updater` — Update codemaps and documentation
- `docs-lookup` — Fetch current library docs via Context7
- `planner` — Implementation planning for complex features
- `tdd-guide` — Test-driven development enforcement

## Commands

- `/prp-prd` — Interactive PRD generator
- `/prp-plan` — Create feature implementation plan
- `/prp-implement` — Execute an implementation plan
- `/code-review` — Review local changes or a GitHub PR
- `/plan` — Restate requirements and create implementation plan
- `/aside` — Simplify and refine recently changed code
- `/update-docs` — Update project documentation
- `/update-codemaps` — Update CODEMAPS files
- `/skill-create` — Create a new skill
- `/learn-eval` — Evaluate and learn from session

## Rules

Common coding standards loaded into every session: coding style, testing, security, performance, hooks, patterns, code review, agent orchestration.

## Install

```sh
claude plugin install development-lifecycle@mmalyska/claude-plugins
```
```

- [ ] **Step 6: Verify file counts**

```bash
echo "Agents: $(ls plugins/development-lifecycle/agents/ | wc -l) (expected 7)"
echo "Commands: $(ls plugins/development-lifecycle/commands/ | wc -l) (expected 10)"
echo "Rules: $(ls plugins/development-lifecycle/rules/common/ | wc -l) (expected 8)"
echo "Skills: $(ls plugins/development-lifecycle/skills/ | wc -l) (expected 1)"
```

- [ ] **Step 7: Commit**

```bash
git add plugins/development-lifecycle/
git commit -m "feat: populate development-lifecycle plugin"
```

---

### Task 5: Populate dotnet plugin

**Files:**
- Create: `plugins/dotnet/agents/csharp-reviewer.md`
- Create: `plugins/dotnet/agents/database-reviewer.md`
- Create: `plugins/dotnet/rules/csharp/` (5 rule files)
- Create: `plugins/dotnet/README.md`

- [ ] **Step 1: Copy agents and rules**

```bash
CHEZMOI=~/.local/share/chezmoi/home/dot_claude
mkdir -p plugins/dotnet/agents plugins/dotnet/rules/csharp

cp "$CHEZMOI/agents/csharp-reviewer.md"   plugins/dotnet/agents/
cp "$CHEZMOI/agents/database-reviewer.md" plugins/dotnet/agents/

cp "$CHEZMOI/rules/csharp/coding-style.md" plugins/dotnet/rules/csharp/
cp "$CHEZMOI/rules/csharp/hooks.md"        plugins/dotnet/rules/csharp/
cp "$CHEZMOI/rules/csharp/patterns.md"     plugins/dotnet/rules/csharp/
cp "$CHEZMOI/rules/csharp/security.md"     plugins/dotnet/rules/csharp/
cp "$CHEZMOI/rules/csharp/testing.md"      plugins/dotnet/rules/csharp/
```

- [ ] **Step 2: Create README**

`plugins/dotnet/README.md`:
```markdown
# dotnet

.NET/C# development agents and rules for Claude Code.

## Agents

- `csharp-reviewer` — C# code review: async patterns, nullable types, LINQ, security, performance
- `database-reviewer` — PostgreSQL query optimization, schema design, security

## Rules

C#-specific coding style, testing (xUnit + Moq), security, hooks (formatters/analyzers), and patterns targeting .NET 10.

## Install

```sh
claude plugin install dotnet@mmalyska/claude-plugins
```
```

- [ ] **Step 3: Verify and commit**

```bash
echo "Agents: $(ls plugins/dotnet/agents/ | wc -l) (expected 2)"
echo "Rules: $(ls plugins/dotnet/rules/csharp/ | wc -l) (expected 5)"
git add plugins/dotnet/
git commit -m "feat: populate dotnet plugin"
```

---

### Task 6: Populate frontend plugin

**Files:**
- Create: `plugins/frontend/rules/web/` (7 rule files)
- Create: `plugins/frontend/rules/typescript/` (5 rule files)
- Create: `plugins/frontend/README.md`

- [ ] **Step 1: Copy rules**

```bash
CHEZMOI=~/.local/share/chezmoi/home/dot_claude
mkdir -p plugins/frontend/rules/web plugins/frontend/rules/typescript

cp "$CHEZMOI/rules/web/coding-style.md"   plugins/frontend/rules/web/
cp "$CHEZMOI/rules/web/design-quality.md" plugins/frontend/rules/web/
cp "$CHEZMOI/rules/web/hooks.md"          plugins/frontend/rules/web/
cp "$CHEZMOI/rules/web/patterns.md"       plugins/frontend/rules/web/
cp "$CHEZMOI/rules/web/performance.md"    plugins/frontend/rules/web/
cp "$CHEZMOI/rules/web/security.md"       plugins/frontend/rules/web/
cp "$CHEZMOI/rules/web/testing.md"        plugins/frontend/rules/web/

cp "$CHEZMOI/rules/typescript/coding-style.md" plugins/frontend/rules/typescript/
cp "$CHEZMOI/rules/typescript/hooks.md"        plugins/frontend/rules/typescript/
cp "$CHEZMOI/rules/typescript/patterns.md"     plugins/frontend/rules/typescript/
cp "$CHEZMOI/rules/typescript/security.md"     plugins/frontend/rules/typescript/
cp "$CHEZMOI/rules/typescript/testing.md"      plugins/frontend/rules/typescript/
```

- [ ] **Step 2: Create README**

`plugins/frontend/README.md`:
```markdown
# frontend

React/Next.js and TypeScript rules for Claude Code.

## Rules

**Web:** coding style (CSS custom properties, semantic HTML, animation), design quality (anti-template policy, hierarchy), testing (visual regression, a11y, cross-browser), performance (Core Web Vitals, bundle budgets), patterns (state management, data fetching), hooks, security (CSP, XSS prevention).

**TypeScript:** coding style, patterns, testing, hooks (ESLint/Prettier/tsc), security.

## Install

```sh
claude plugin install frontend@mmalyska/claude-plugins
```
```

- [ ] **Step 3: Verify and commit**

```bash
echo "Web rules: $(ls plugins/frontend/rules/web/ | wc -l) (expected 7)"
echo "TS rules: $(ls plugins/frontend/rules/typescript/ | wc -l) (expected 5)"
git add plugins/frontend/
git commit -m "feat: populate frontend plugin"
```

---

### Task 7: Create stub plugins (renovate, devcontainer, android)

These plugins are scaffolded but have no content yet — content comes in Plan 2.

**Files:**
- Create: `plugins/renovate/README.md`
- Create: `plugins/devcontainer/README.md`
- Create: `plugins/android/README.md`

- [ ] **Step 1: Create stub READMEs**

`plugins/renovate/README.md`:
```markdown
# renovate

Renovate config authoring skills for Claude Code.

Skills for extending `mmalyska/renovate-config` presets, writing custom regex managers (YAML/Dockerfile/DevContainer), and configuring datasource-specific automerge rules.

> **Status:** Coming in Plan 2.

## Install

```sh
claude plugin install renovate@mmalyska/claude-plugins
```
```

`plugins/devcontainer/README.md`:
```markdown
# devcontainer

Dev container setup skills for Claude Code.

Skills for building custom GHCR-published devcontainer images, injecting secrets via `devcontainer.env`, and integrating Renovate for image digest pinning.

> **Status:** Coming in Plan 2.

## Install

```sh
claude plugin install devcontainer@mmalyska/claude-plugins
```
```

`plugins/android/README.md`:
```markdown
# android

Android mobile development agents and rules for Claude Code.

> **Status:** Coming soon.

## Install

```sh
claude plugin install android@mmalyska/claude-plugins
```
```

- [ ] **Step 2: Commit stubs**

```bash
git add plugins/renovate/ plugins/devcontainer/ plugins/android/
git commit -m "chore: add stub plugins for renovate, devcontainer, android"
```

---

### Task 8: Create personal-essentials plugin

**Files:**
- Create: `plugins/personal-essentials/commands/personal-setup.md`
- Create: `plugins/personal-essentials/README.md`

- [ ] **Step 1: Create /personal-setup command**

`plugins/personal-essentials/commands/personal-setup.md`:
```markdown
Install all mmalyska/claude-plugins on this machine.

Run the following commands in sequence:

```bash
claude plugin install git-workflows@mmalyska/claude-plugins
claude plugin install development-lifecycle@mmalyska/claude-plugins
claude plugin install dotnet@mmalyska/claude-plugins
claude plugin install frontend@mmalyska/claude-plugins
claude plugin install renovate@mmalyska/claude-plugins
claude plugin install devcontainer@mmalyska/claude-plugins
claude plugin install android@mmalyska/claude-plugins
```

After installation, restart Claude Code for all agents, commands, rules, and skills to take effect.
```

- [ ] **Step 2: Create README**

`plugins/personal-essentials/README.md`:
```markdown
# personal-essentials

Meta-plugin that installs all mmalyska/claude-plugins at once.

## Usage

After installing this plugin, run `/personal-setup` in Claude Code to install all remaining plugins.

## Quick start (new machine)

```sh
claude plugin add marketplace github:mmalyska/claude-plugins
claude plugin install personal-essentials@mmalyska/claude-plugins
# Then in Claude Code: /personal-setup
```
```

- [ ] **Step 3: Commit**

```bash
git add plugins/personal-essentials/
git commit -m "feat: add personal-essentials meta-plugin"
```

---

### Task 9: Register marketplace and verify installation

- [ ] **Step 1: Push all commits to GitHub**

```bash
git push
```

Expected: all commits pushed, visible at `https://github.com/mmalyska/claude-plugins`.

- [ ] **Step 2: Register the marketplace in Claude Code**

```bash
claude plugin add marketplace github:mmalyska/claude-plugins
```

Expected: no errors, marketplace listed in `/plugin` UI.

- [ ] **Step 3: Install personal-essentials**

```bash
claude plugin install personal-essentials@mmalyska/claude-plugins
```

Expected: plugin installed at `~/.claude/plugins/cache/mmalyska/claude-plugins/personal-essentials/`.

- [ ] **Step 4: Install all domain plugins**

```bash
claude plugin install git-workflows@mmalyska/claude-plugins
claude plugin install development-lifecycle@mmalyska/claude-plugins
claude plugin install dotnet@mmalyska/claude-plugins
claude plugin install frontend@mmalyska/claude-plugins
```

Expected: each plugin installs without errors.

- [ ] **Step 5: Verify agents appear in Claude Code**

Open a new Claude Code session and verify:
```
/agents
```
Expected: `planner`, `architect`, `tdd-guide`, `code-reviewer`, `build-error-resolver`, `doc-updater`, `docs-lookup`, `csharp-reviewer`, `database-reviewer` all appear in the list.

- [ ] **Step 6: Verify commands appear**

```
/
```
Expected: `/prp-pr`, `/prp-commit`, `/prp-prd`, `/prp-plan`, `/prp-implement`, `/code-review`, `/plan`, `/aside`, `/personal-setup` all appear in the command list.

---

### Task 10: Add chezmoi bootstrap script

**Files:**
- Create: `~/.local/share/chezmoi/home/dot_claude/run_once_install-claude-plugins.sh`

- [ ] **Step 1: Create bootstrap script in chezmoi**

`~/.local/share/chezmoi/home/run_once_install-claude-plugins.sh` — note: must be at `home/` level (not inside `home/dot_claude/`), otherwise chezmoi treats it as a regular file rather than a script to execute:
```bash
#!/bin/bash
set -euo pipefail

claude plugin add marketplace github:mmalyska/claude-plugins
claude plugin install personal-essentials@mmalyska/claude-plugins
claude plugin install git-workflows@mmalyska/claude-plugins
claude plugin install development-lifecycle@mmalyska/claude-plugins
claude plugin install dotnet@mmalyska/claude-plugins
claude plugin install frontend@mmalyska/claude-plugins
claude plugin install renovate@mmalyska/claude-plugins
claude plugin install devcontainer@mmalyska/claude-plugins
claude plugin install android@mmalyska/claude-plugins
```

Note: chezmoi runs `run_once_` scripts once per machine. The filename hash ensures it re-runs only when the file content changes.

- [ ] **Step 2: Commit the bootstrap script to chezmoi**

```bash
cd ~/.local/share/chezmoi
git add home/run_once_install-claude-plugins.sh
git commit -m "feat: add claude plugins bootstrap script"
git push
```

---

## What's Next (Plan 2)

Plan 2 will create the new content that doesn't yet exist:
- `development-lifecycle` — 7 lifecycle commands (`/spec`, `/plan`, `/build`, `/test`, `/review`, `/simplify`, `/ship`) forked and adapted from addyosmani/agent-skills
- `renovate` — skills for extending `mmalyska/renovate-config`, custom regex managers, automerge patterns
- `devcontainer` — skills for GHCR image pipelines and secrets injection
