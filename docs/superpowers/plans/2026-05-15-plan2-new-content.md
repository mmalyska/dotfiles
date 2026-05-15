# Plan 2: New Plugin Content — Lifecycle Commands, Renovate, Devcontainer

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add new content to three plugins in `mmalyska/claude-plugins` — 6 lifecycle commands for `development-lifecycle`, skills and an auditor agent for `renovate`, and skills and an auditor agent for `devcontainer`.

**Architecture:** Each plugin is independently developed and committed. The `development-lifecycle` commands adapt the addyosmani/agent-skills 7-stage model (`/spec→/plan→/build→/test→/review→/simplify→/ship`) with our tdd-guide/code-reviewer agents and chezmoi path conventions. The `renovate` and `devcontainer` skills encapsulate patterns from `mmalyska/renovate-config` and `mmalyska/home-ops` as reference material — so Claude can generate correct configs without reading those repos each session.

**Tech Stack:** Markdown command/skill/agent files, Claude Code plugin format, GitHub Actions (reference), Renovate JSON5, devcontainer.json

---

## Scope Note

These three plugins are independent subsystems. They can be split into separate plan files; this combined plan is provided for convenience. Each plugin section produces working, independently usable content.

## File Structure

### development-lifecycle (Tasks 1–6)

```
plugins/development-lifecycle/
├── commands/
│   ├── spec.md          ← NEW: problem-first spec writer
│   ├── build.md         ← NEW: TDD implementation loop
│   ├── test.md          ← NEW: test runner + 80% coverage gate
│   ├── review.md        ← NEW: five-axis review with CRITICAL gate
│   ├── simplify.md      ← NEW: refactor + immutability enforcement
│   └── ship.md          ← NEW: commit + PR
└── README.md            ← MODIFY: add lifecycle flow section
```

### renovate (Tasks 7–10)

```
plugins/renovate/
├── agents/
│   └── renovate-auditor.md          ← NEW
├── skills/
│   ├── extending-presets/
│   │   └── SKILL.md                 ← NEW
│   ├── custom-regex-managers/
│   │   └── SKILL.md                 ← NEW
│   └── automerge-rules/
│       └── SKILL.md                 ← NEW
└── README.md                        ← MODIFY
```

### devcontainer (Tasks 11–14)

```
plugins/devcontainer/
├── agents/
│   └── devcontainer-auditor.md      ← NEW
├── skills/
│   ├── ghcr-image-pipeline/
│   │   └── SKILL.md                 ← NEW
│   ├── secrets-injection/
│   │   └── SKILL.md                 ← NEW
│   └── renovate-digest-pinning/
│       └── SKILL.md                 ← NEW
└── README.md                        ← MODIFY
```

---

## Task 1: /spec command

**Files:**
- Create: `plugins/development-lifecycle/commands/spec.md`

**Context:** This is the first step in the lifecycle. It replaces `/prp-prd`. The user invokes `/spec` (optionally with a brief idea) and Claude walks them through defining the problem before any code is written. Saves to `docs/superpowers/specs/` to match the chezmoi convention. Source reference: `~/projects/agent-skills/.claude/commands/spec.md` for structure inspiration.

- [ ] **Step 1: Define acceptance criteria**

The finished file must:
- Have YAML frontmatter with `description` field
- Describe an interaction flow (ask questions → generate spec → gate)
- Include the spec output path `docs/superpowers/specs/YYYY-MM-DD-<name>.md`
- Have a verification gate before directing user to `/plan`

Run to confirm nothing exists yet:
```bash
ls ~/projects/claude-plugins/plugins/development-lifecycle/commands/spec.md 2>/dev/null && echo EXISTS || echo "OK - does not exist"
```
Expected: `OK - does not exist`

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/development-lifecycle/commands/spec.md` with this exact content:

```markdown
---
description: Define the problem before writing code — interactive spec with verification gate
argument-hint: [feature idea, or blank to start with questions]
---

# Spec Command

**Input**: $ARGUMENTS

---

Kick off spec-driven development. Understand what to build and why before touching code.

## Phase 1 — UNDERSTAND

If `$ARGUMENTS` is provided, restate it:

> I understand you want to build: {restatement}
> Is this correct?

If blank, ask:

> What do you want to build? Describe in a few sentences.

**GATE**: Wait for confirmation before proceeding.

---

## Phase 2 — CLARIFY

Present these questions together (user can answer in one reply):

> **Problem & Users**
> 1. Who has this problem? (specific role, not just "users")
> 2. What pain are they experiencing today?
> 3. Why does the current solution fail them?
> 4. How will you know the problem is solved?
>
> **Scope**
> 5. What are the 2–3 must-have capabilities for v1?
> 6. What is explicitly out of scope?
> 7. Any technical constraints? (stack, performance, security, deadlines)

**GATE**: Wait for answers.

---

## Phase 3 — GENERATE SPEC

Determine the kebab-case name from the feature idea. Save to:
`docs/superpowers/specs/YYYY-MM-DD-<kebab-name>.md`

Use today's date (check with `date +%Y-%m-%d` if needed). Create the directory if it doesn't exist.

Write the spec file with this template:

```md
# [Feature Name] Spec

**Date:** YYYY-MM-DD
**Status:** Draft

## Problem

[2–3 sentences: who has what problem, what is the cost of not solving it]

## Users

**Primary:** [specific description of the target user]
**Not for:** [who this is NOT for, and why]

## Success Criteria

- [ ] [Measurable outcome 1]
- [ ] [Measurable outcome 2]
- [ ] [Measurable outcome 3]

## Scope

### Must Have (v1)
- [Capability 1]
- [Capability 2]

### Out of Scope
- [Deferred item 1] — [why]
- [Deferred item 2] — [why]

## Technical Notes

[Any constraints, stack choices, or integration points]

## Open Questions

- [ ] [Unresolved question that could change the approach]
```

---

## Phase 4 — CONFIRM AND HAND OFF

Show the spec to the user. Ask:

> Spec saved to `docs/superpowers/specs/{filename}.md`
>
> Does this capture the problem correctly?
> - **Yes** → continue to planning with: `/plan docs/superpowers/specs/{filename}.md`
> - **Revise** → describe what to change

**GATE**: Do not proceed to planning until the user confirms the spec.

---

## Lifecycle Position

```
/spec → /plan → loop(/build → /test → /review → /simplify) → /ship
```

This command produces a spec doc. The next step is `/plan` to decompose the spec into tasks.
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/development-lifecycle/commands/spec.md
grep "description:" ~/projects/claude-plugins/plugins/development-lifecycle/commands/spec.md | head -1
grep -c "^## Phase" ~/projects/claude-plugins/plugins/development-lifecycle/commands/spec.md
```
Expected: file exists, has `description:` frontmatter, shows `4` phases.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/development-lifecycle/commands/spec.md
git commit -m "feat(development-lifecycle): add /spec lifecycle command"
```

---

## Task 2: /build command

**Files:**
- Create: `plugins/development-lifecycle/commands/build.md`

**Context:** `/build` is the third lifecycle step (after `/spec` and `/plan`). It drives TDD-first implementation of a single task. It delegates to the `tdd-guide` agent for the RED-GREEN-REFACTOR loop. The user invokes it with a task description; Claude picks up from the plan if no input given. Source reference: `~/projects/agent-skills/.claude/commands/build.md`.

- [ ] **Step 1: Define acceptance criteria**

The finished file must:
- Reference `tdd-guide` agent
- Have the RED-GREEN-REFACTOR steps explicitly
- Have a gate: tests must pass before marking done
- Describe how to pick the task from a plan

Run:
```bash
ls ~/projects/claude-plugins/plugins/development-lifecycle/commands/build.md 2>/dev/null && echo EXISTS || echo "OK - does not exist"
```
Expected: `OK - does not exist`

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/development-lifecycle/commands/build.md`:

```markdown
---
description: Implement the next task with TDD — RED/GREEN/REFACTOR loop, then commit
argument-hint: [task description, or blank to pick next pending task from tasks/plan.md]
---

# Build Command

**Input**: $ARGUMENTS

---

Implement a task using strict test-driven development. Delegate the TDD loop to the `tdd-guide` agent.

## Phase 0 — LOAD TASK

If `$ARGUMENTS` is provided, treat it as the task description.

Otherwise, read `tasks/plan.md` and select the next unchecked task (`- [ ]`). If no `tasks/plan.md` exists, stop:

```
No plan found. Run /plan first to create a task list.
```

Read the task's acceptance criteria carefully before writing any code.

---

## Phase 1 — TDD LOOP

Use the `tdd-guide` agent to implement the task. The loop is:

### RED: Write a failing test

1. Write a test that describes the expected behavior **before** touching implementation.
2. Run the test suite to confirm the new test **fails**.
   ```bash
   # Auto-detect runner; examples:
   pnpm test -- --testPathPattern=<test-file>
   pytest tests/test_foo.py::test_bar -v
   cargo test test_bar
   go test ./... -run TestBar
   ```
3. If the test passes without implementation, the test is wrong — revise it.

### GREEN: Implement minimally

4. Write the **minimum** code to make the test pass. Do not over-engineer.
5. Run the test again — confirm it **passes**.
6. Run the full test suite to check for regressions.

### REFACTOR

7. Clean the implementation: extract helpers, clarify names, remove duplication.
8. Run the full test suite again — all must stay green.
9. No behavior changes in this step.

---

## Phase 2 — VERIFY

Run all available project checks:

```bash
# Type check (if applicable to the project)
# Lint
# Full test suite
# Build
```

**GATE**: Do not commit if tests fail or the build is broken. Fix the failures before proceeding.

---

## Phase 3 — COMMIT

```bash
git add -p   # Stage only the relevant changes — review each hunk
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

[optional body if behavior needs explanation]
EOF
)"
```

Types: `feat`, `fix`, `test`, `refactor`, `chore`, `perf`

---

## Phase 4 — REPORT

```
DONE: [task name]

Tests: N passing, N new tests added
Files changed: [list]
Commit: [hash]

Next: /test to verify coverage, or /build again for the next task
```

---

## Lifecycle Position

```
/spec → /plan → loop(/build → /test → /review → /simplify) → /ship
                      ^^^^
                   You are here
```
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/development-lifecycle/commands/build.md
grep "tdd-guide" ~/projects/claude-plugins/plugins/development-lifecycle/commands/build.md
grep -c "^## Phase" ~/projects/claude-plugins/plugins/development-lifecycle/commands/build.md
```
Expected: file exists, contains `tdd-guide`, shows `4` phases.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/development-lifecycle/commands/build.md
git commit -m "feat(development-lifecycle): add /build lifecycle command"
```

---

## Task 3: /test command

**Files:**
- Create: `plugins/development-lifecycle/commands/test.md`

**Context:** `/test` is the fourth lifecycle step — a standalone verification gate run after `/build`. It detects the test runner, runs the suite, checks 80% coverage, and calls `build-error-resolver` on failure. This is a NEW command with no equivalent in the existing plugin. Source reference: `~/projects/agent-skills/.claude/commands/test.md` (addyosmani's is TDD-focused; ours is a standalone runner gate).

- [ ] **Step 1: Define acceptance criteria**

The file must:
- List test runner detection logic (bun, pnpm, pytest, cargo, go)
- Have a 80% coverage gate with STOP behavior
- Reference `build-error-resolver` agent on failure
- Have a PASS/FAIL report format

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/development-lifecycle/commands/test.md`:

```markdown
---
description: Run tests and enforce 80% coverage gate — calls build-error-resolver on failure
---

# Test Command

Run the project's test suite and verify the 80% minimum coverage requirement.

---

## Phase 1 — DETECT TEST RUNNER

Identify the runner from lockfiles and config:

| Signal | Runner | Test Command | Coverage Command |
|--------|--------|-------------|-----------------|
| `bun.lockb` | Bun | `bun test` | `bun test --coverage` |
| `pnpm-lock.yaml` + Jest config | pnpm/Jest | `pnpm test` | `pnpm test -- --coverage` |
| `pnpm-lock.yaml` + Vitest | pnpm/Vitest | `pnpm test` | `pnpm test -- --coverage` |
| `package-lock.json` | npm | `npm test` | `npm test -- --coverage` |
| `pytest.ini` / `pyproject.toml[pytest]` | pytest | `pytest` | `pytest --cov --cov-report=term-missing` |
| `Cargo.toml` | cargo | `cargo test` | `cargo tarpaulin` or `cargo llvm-cov` |
| `go.mod` | go | `go test ./...` | `go test ./... -cover` |

If multiple signals exist (e.g. `package.json` with vitest configured), read `package.json` scripts to determine the right command:
```bash
cat package.json | python3 -c "import sys,json; s=json.load(sys.stdin)['scripts']; print(s.get('test',''),s.get('coverage',''))"
```

---

## Phase 2 — RUN TESTS

```bash
[detected test command]
```

Record:
- Total test count
- Passing count
- Failing count (with names)
- Test duration

---

## Phase 3 — COVERAGE CHECK

```bash
[detected coverage command]
```

Extract the overall coverage percentage from the output.

**GATE — 80% minimum:**

If coverage ≥ 80%: proceed to Phase 4.

If coverage < 80%, **STOP** and report:

```
COVERAGE GATE FAILED

Coverage: XX% (target: ≥80%)

Untested areas (< 50% coverage):
  src/auth/token.ts        0%
  src/api/users.ts        41%

To add tests for these files, run /build.
If the test failures are caused by a build or config error, use the build-error-resolver agent.
```

Do not proceed to `/review` or `/ship` until coverage passes.

---

## Phase 4 — REPORT

On all tests passing and coverage ≥ 80%:

```
TESTS PASSED ✓

Tests:    N passing, 0 failing
Coverage: XX% ✓
Duration: Xs

Next: /review to check the implementation
```

On test failures:

```
TESTS FAILED

N passing, M failing

Failing tests:
  [test name] — [error message]
  [test name] — [error message]

Fix suggestions:
  - Run /build to add missing tests or fix implementation
  - Use the build-error-resolver agent for build/config errors
```

---

## Lifecycle Position

```
/spec → /plan → loop(/build → /test → /review → /simplify) → /ship
                              ^^^^
                           You are here
```
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/development-lifecycle/commands/test.md
grep "80%" ~/projects/claude-plugins/plugins/development-lifecycle/commands/test.md
grep "build-error-resolver" ~/projects/claude-plugins/plugins/development-lifecycle/commands/test.md
```
Expected: file exists, contains `80%` and `build-error-resolver`.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/development-lifecycle/commands/test.md
git commit -m "feat(development-lifecycle): add /test lifecycle command with 80% coverage gate"
```

---

## Task 4: /review command

**Files:**
- Create: `plugins/development-lifecycle/commands/review.md`

**Context:** `/review` is the fifth lifecycle step. It runs a five-axis code review using the `code-reviewer` agent and, for domain-specific code, the `csharp-reviewer` agent. It has a hard CRITICAL gate — it blocks progression to `/simplify` or `/ship` until all CRITICAL issues are resolved. Source reference: `~/projects/agent-skills/.claude/commands/review.md` and the existing `plugins/development-lifecycle/commands/code-review.md`.

- [ ] **Step 1: Define acceptance criteria**

The file must:
- Describe five-axis review (correctness, readability, architecture, security, performance)
- Reference `code-reviewer` agent as primary reviewer
- Reference `csharp-reviewer` for `.cs`/`.csproj` files
- Have CRITICAL/HIGH/MEDIUM/LOW severity table
- Have a GATE that blocks on CRITICAL

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/development-lifecycle/commands/review.md`:

```markdown
---
description: Five-axis code review with CRITICAL gate — blocks on security/data-loss issues
argument-hint: [blank for uncommitted changes]
---

# Review Command

Run a structured code review across five quality axes. Blocks progression if CRITICAL issues are found.

---

## Phase 1 — GATHER

```bash
git diff --name-only HEAD
```

If no changed files: stop with "Nothing to review — no uncommitted changes."

List the changed files by type:
- Source files (`.ts`, `.cs`, `.go`, `.py`, etc.)
- Test files
- Config files
- Documentation

---

## Phase 2 — REVIEW

Use the **code-reviewer** agent to review all changed source and test files across five axes:

| Axis | What to check |
|------|---------------|
| **Correctness** | Logic errors, off-by-ones, null handling, edge cases, race conditions |
| **Readability** | Clear names, straightforward logic, no deep nesting (>4 levels), no magic numbers |
| **Architecture** | Follows existing patterns, clean boundaries, appropriate abstraction level |
| **Security** | No hardcoded secrets, input validated, SQL/XSS/injection safe, auth checked |
| **Performance** | No N+1 queries, no unbounded loops, no unnecessary allocations |

**Domain-specific reviewers** (invoke when applicable):
- Changed files include `.cs`, `.csproj`, or `.sln` → also use **csharp-reviewer** agent
- Changed files include React/TypeScript frontend → apply `rules/web/` guidelines

---

## Phase 3 — CATEGORIZE

Assign severity to each finding:

| Severity | Meaning | Action |
|---------|---------|--------|
| **CRITICAL** | Security vulnerability or data loss risk | Must fix before any next step |
| **HIGH** | Bug or logic error likely to cause problems | Should fix before merging |
| **MEDIUM** | Code quality or maintainability issue | Fix recommended |
| **LOW** | Style nit or minor suggestion | Optional |

---

## Phase 4 — GATE

**If any CRITICAL findings:**

```
REVIEW BLOCKED — N CRITICAL issue(s) must be fixed

[CRITICAL] src/auth/token.ts:42 — JWT secret read from process.env without validation;
           null secret causes tokens to verify against empty string.
           Fix: throw if SECRET is not set at startup.

Fix all CRITICAL issues and run /review again.
```

Do NOT proceed until CRITICAL count is 0.

**If CRITICAL = 0, HIGH > 0:**

```
REVIEW PASSED WITH WARNINGS — N HIGH issue(s) found

[HIGH] src/api/users.ts:88 — Missing input validation on email field allows
       empty string to be inserted into the database.

These issues should be fixed before merging. You may proceed to /simplify or /ship,
but address the HIGH findings in your next /build cycle.
```

**If only MEDIUM/LOW or no findings:**

```
REVIEW PASSED ✓

[MEDIUM] src/cache/store.ts:15 — Consider extracting cache key construction to a helper.
[LOW]    src/api/index.ts:3  — Unused import 'Router'.

Next: /simplify to clean up, or /ship to commit and create PR.
```

---

## Lifecycle Position

```
/spec → /plan → loop(/build → /test → /review → /simplify) → /ship
                                       ^^^^^^^^
                                     You are here
```
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/development-lifecycle/commands/review.md
grep "code-reviewer" ~/projects/claude-plugins/plugins/development-lifecycle/commands/review.md
grep "CRITICAL" ~/projects/claude-plugins/plugins/development-lifecycle/commands/review.md | wc -l
```
Expected: file exists, contains `code-reviewer`, has multiple CRITICAL references.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/development-lifecycle/commands/review.md
git commit -m "feat(development-lifecycle): add /review lifecycle command with CRITICAL gate"
```

---

## Task 5: /simplify command

**Files:**
- Create: `plugins/development-lifecycle/commands/simplify.md`

**Context:** `/simplify` is the sixth lifecycle step — an optional but recommended cleanup pass before shipping. It reduces complexity without changing behavior. It enforces the immutability rule from the coding-style rules: never mutate objects, always create new ones. Source reference: `~/projects/agent-skills/.claude/commands/code-simplify.md`.

- [ ] **Step 1: Define acceptance criteria**

The file must:
- Target recently changed files (from git diff) by default
- List specific simplification opportunities to scan for
- Include the immutability rule with a code example
- Require test verification after each change
- Report what was changed

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/development-lifecycle/commands/simplify.md`:

```markdown
---
description: Simplify code for clarity and maintainability — reduce complexity without changing behavior
argument-hint: [blank for recent changes, or path/to/file]
---

# Simplify Command

**Input**: $ARGUMENTS (defaults to recently changed files)

---

Reduce complexity in the target code without changing any behavior. Apply changes incrementally and verify tests pass after each one.

## Phase 1 — SCOPE

Identify target files:
- If `$ARGUMENTS` provided: use that file or directory.
- Otherwise: `git diff --name-only HEAD` — use recently changed source files (skip test files and generated files).

If no files to target: report "No recent changes to simplify."

---

## Phase 2 — ANALYZE

For each target file, scan for these specific opportunities:

| Pattern | Simplification |
|---------|---------------|
| Nesting depth > 4 levels | Guard clauses / early returns |
| Functions > 50 lines | Split by single responsibility |
| Mutation of existing objects | Replace with immutable update |
| Generic names (`data`, `result`, `temp`) | Descriptive names that reveal intent |
| Duplicated logic across functions | Extract shared helper |
| Dead code (unreachable, unused exports) | Remove after confirming with grep |
| Nested ternaries | Rewrite as if/else or switch |
| Magic numbers | Extract as named constants |

Build a list of proposed changes before making any of them.

---

## Phase 3 — IMMUTABILITY CHECK (CRITICAL)

The coding-style rules require immutable data patterns. Flag and fix any violations:

```
// WRONG — mutates existing object
obj.field = value
array.push(item)
Object.assign(target, source)

// CORRECT — returns new copy
const updated = { ...obj, field: value }
const extended = [...array, item]
const merged = { ...target, ...source }
```

Every mutation found counts as a simplification opportunity.

---

## Phase 4 — APPLY INCREMENTALLY

For each proposed change:
1. Apply the single change.
2. Run tests immediately:
   ```bash
   [project test command]
   ```
3. If tests pass: keep the change, move to the next.
4. If tests fail: **revert this specific change** and note it in the report.

Never batch simplifications — apply one, verify, then apply the next.

---

## Phase 5 — REPORT

```
SIMPLIFIED

Changes applied (N):
  src/auth/token.ts:42  — guard clause replaces 3-level nesting
  src/cache/store.ts:15 — extracted cacheKey() helper
  src/api/users.ts:30   — replaced object mutation with immutable update

Reverted (0): none

Tests: all passing ✓

Next: /ship to commit and create PR
```

If changes were reverted:
```
SIMPLIFIED WITH NOTES

Changes applied (N): ...

Reverted (M) — tests failed after these changes:
  src/utils/parse.ts:88 — attempted extraction failed (tests broke); left as-is

Review the reverted cases manually.
```

---

## Lifecycle Position

```
/spec → /plan → loop(/build → /test → /review → /simplify) → /ship
                                                 ^^^^^^^^^^
                                               You are here
```
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/development-lifecycle/commands/simplify.md
grep "immutab" ~/projects/claude-plugins/plugins/development-lifecycle/commands/simplify.md
grep -c "^## Phase" ~/projects/claude-plugins/plugins/development-lifecycle/commands/simplify.md
```
Expected: file exists, contains `immutab`, shows `5` phases.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/development-lifecycle/commands/simplify.md
git commit -m "feat(development-lifecycle): add /simplify lifecycle command"
```

---

## Task 6: /ship command + README update

**Files:**
- Create: `plugins/development-lifecycle/commands/ship.md`
- Modify: `plugins/development-lifecycle/README.md`

**Context:** `/ship` is the final lifecycle step. It does pre-flight checks, creates a conventional commit, pushes to a branch, and opens a PR with a template. It assumes `/review` and `/simplify` have already run. Much simpler than addyosmani's fan-out version — this is intentional, as we separate review from shipping. Source reference: `~/projects/agent-skills/.claude/commands/ship.md`.

- [ ] **Step 1: Define acceptance criteria**

`ship.md` must:
- Check for secrets/debug statements (pre-flight)
- Create a conventional commit with the right format
- Handle branch creation if on main
- Create a PR via `gh pr create`

The README update must add a new `## Lifecycle (7-stage)` section documenting the flow.

- [ ] **Step 2: Create ship.md**

Create `~/projects/claude-plugins/plugins/development-lifecycle/commands/ship.md`:

```markdown
---
description: Final lifecycle step — pre-flight checks, conventional commit, push, and PR
argument-hint: [commit message hint, or blank to auto-generate from diff]
---

# Ship Command

**Input**: $ARGUMENTS

---

Run pre-flight checks, create a conventional commit, and open a pull request.

## Phase 1 — PRE-FLIGHT

```bash
git status
git diff --stat HEAD
```

Check for blockers:

| Check | Command | Block if |
|-------|---------|---------|
| No hardcoded secrets | `grep -rn "api_key\|password\s*=\|token\s*=" --include="*.ts" --include="*.py" --include="*.cs" .` | Any match in non-test files |
| No debug statements | `grep -rn "console\.log\|debugger\|breakpoint()" --include="*.ts" .` | Any match in non-test files |
| No TODO/FIXME left | `grep -rn "TODO\|FIXME\|HACK" $(git diff --name-only HEAD)` | Match in files introduced in this change |

If any pre-flight check fails, **STOP**:

```
PRE-FLIGHT FAILED

[secret] src/config.ts:12 — 'password = "admin123"' detected
Remove the secret and use environment variables instead.
```

---

## Phase 2 — COMMIT MESSAGE

Analyze the diff to determine the type and scope:

| Type | When to use |
|------|------------|
| `feat` | New feature or user-visible capability |
| `fix` | Bug fix |
| `refactor` | Code restructuring without behavior change |
| `test` | Adding or improving tests |
| `docs` | Documentation only |
| `chore` | Tooling, deps, config |
| `perf` | Performance improvement |
| `ci` | CI/CD changes |

If `$ARGUMENTS` is provided, use as a hint for the message.
Otherwise, generate the message from the diff.

Format: `<type>(<scope>): <description>`
- Scope is optional but recommended (e.g. `auth`, `api`, `ui`)
- Description: imperative, lowercase, no period, ≤72 chars

```bash
git add [files to stage]
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

[optional body: what changed and why, if non-obvious]
EOF
)"
```

---

## Phase 3 — BRANCH CHECK

```bash
git branch --show-current
```

If on `main` or `master` with uncommitted changes already committed:
```bash
# Create feature branch from the last commit
git checkout -b feat/<slug-from-commit-subject>
```

If already on a feature branch: continue.

---

## Phase 4 — PUSH

```bash
git push -u origin "$(git branch --show-current)"
```

---

## Phase 5 — PULL REQUEST

Create the PR using `gh`:

```bash
gh pr create \
  --title "<conventional commit subject line>" \
  --body "$(cat <<'EOF'
## Summary

- [Change 1]
- [Change 2]

## Test Plan

- [ ] Tests pass locally (`/test` ran, coverage ≥ 80%)
- [ ] No CRITICAL review findings (`/review` cleared)
- [ ] No hardcoded secrets or debug statements

## Related

[Link to spec or plan if available in docs/superpowers/]
EOF
)"
```

---

## Phase 6 — REPORT

```
SHIPPED ✓

Commit: abc1234 — feat(auth): add JWT refresh token rotation
Branch: feat/auth-jwt-refresh
PR:     https://github.com/owner/repo/pull/42

Lifecycle complete:
  /spec → /plan → /build → /test → /review → /simplify → /ship ✓
```

---

## Lifecycle Position

```
/spec → /plan → loop(/build → /test → /review → /simplify) → /ship
                                                               ^^^^^
                                                            You are here
```
```

- [ ] **Step 3: Update README.md**

Read the current README and add a `## Lifecycle (7-stage)` section after the `## Commands` section:

Current `## Commands` section ends around line 26. Add this block after it:

```markdown
## Lifecycle (7-stage)

The 7-stage lifecycle commands form an opinionated development pipeline:

```
/spec → /plan → loop(/build → /test → /review → /simplify) → /ship
```

| Command | Stage | Purpose |
|---------|-------|---------|
| `/spec` | Define | Problem-first spec with verification gate |
| `/plan` | Plan | Task decomposition with acceptance criteria |
| `/build` | Implement | TDD loop using `tdd-guide` agent |
| `/test` | Verify | Test runner + 80% coverage gate |
| `/review` | Review | Five-axis review, blocks on CRITICAL issues |
| `/simplify` | Refactor | Cleanup + immutability enforcement |
| `/ship` | Ship | Conventional commit + PR creation |

The older `/prp-prd`, `/prp-plan`, `/prp-implement`, `/code-review` commands remain available as aliases.
```

- [ ] **Step 4: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/development-lifecycle/commands/ship.md
grep "gh pr create" ~/projects/claude-plugins/plugins/development-lifecycle/commands/ship.md
grep "Lifecycle (7-stage)" ~/projects/claude-plugins/plugins/development-lifecycle/README.md
```
Expected: both files exist/updated with expected content.

- [ ] **Step 5: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/development-lifecycle/commands/ship.md plugins/development-lifecycle/README.md
git commit -m "feat(development-lifecycle): add /ship command and lifecycle README section"
```

---

## Task 7: renovate extending-presets skill

**Files:**
- Create: `plugins/renovate/skills/extending-presets/SKILL.md`

**Context:** The `mmalyska/renovate-config` repo has 12 preset files. This skill teaches Claude how to extend the shared preset in a repo's `renovate.json5`. The actual preset contents (fetched from the repo) are embedded as reference. Source: `github.com/mmalyska/renovate-config`.

The 12 presets and their purpose:
- `default.json` — base preset (extends config:base + all standard sub-presets)
- `commit-message.json` — `commitMessageTopic: "{{depName}}"`, no suffix
- `pr-labels.json` — dep/major, dep/minor, dep/patch + datasource labels
- `semantic-commits.json` — feat/fix/ci by update type; scoped by datasource
- `automerge-docker-digest.json` — automerge `digest` updates for docker datasource
- `automerge-github-actions.json` — automerge minor/patch/digest for github-actions, ignoreTests
- `automerge-terraform-providers.json` — automerge minor/patch for terraform-provider
- `automerge-galaxy-collections.json` — automerge minor/patch for galaxy-collection, ignoreTests
- `automerge-galaxy-roles.json` — automerge for Ansible Galaxy roles
- `generic-regex-manager.json5` — YAML/Dockerfile comment-based version extraction
- `devcontainer-regex-manager.json5` — devcontainer.json image version extraction

- [ ] **Step 1: Define acceptance criteria**

The SKILL.md must:
- Have YAML frontmatter with name and description
- List all presets with their purpose
- Show a complete `renovate.json5` example using the base preset
- Show how to add individual sub-presets
- Show the local override pattern for per-repo customization

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/renovate/skills/extending-presets/SKILL.md`:

```markdown
---
name: renovate-extending-presets
description: How to extend mmalyska/renovate-config presets in a repo's renovate.json5, including all available sub-presets and the local override pattern
---

# Extending mmalyska/renovate-config Presets

## When to Use

Use this skill when writing or auditing a `renovate.json5` (or `renovate.json`) that should inherit from the shared `mmalyska/renovate-config` preset. This skill covers the base preset, all sub-presets, and the local override pattern for per-repo customization.

---

## Available Presets

All presets live at `github.com/mmalyska/renovate-config`.

| Preset | Purpose |
|--------|---------|
| `github>mmalyska/renovate-config` | **Base** — extends config:base, enables dependency dashboard, disables rate limiting, enables Docker digest pinning and automerge, plus commit-message, pr-labels, semantic-commits, generic-regex-manager, devcontainer-regex-manager |
| `github>mmalyska/renovate-config:commit-message` | Commit format: `{{depName}}` topic, `to {{newVersion}}` extra, no suffix |
| `github>mmalyska/renovate-config:pr-labels` | Labels: dep/major, dep/minor, dep/patch + renovate/helm, renovate/container, renovate/ansible, renovate/terraform, renovate/github-action |
| `github>mmalyska/renovate-config:semantic-commits` | feat for minor, fix for patch, ci for github-actions; scoped by datasource (docker-image, helm-chart, terraform-provider, ansible-collection, ansible-role, github-action) |
| `github>mmalyska/renovate-config:automerge-docker-digest` | Automerge docker digest updates via branch |
| `github>mmalyska/renovate-config:automerge-github-actions` | Automerge minor/patch/digest for github-actions via branch, ignoreTests |
| `github>mmalyska/renovate-config:automerge-terraform-providers` | Automerge minor/patch for terraform-provider via branch |
| `github>mmalyska/renovate-config:automerge-galaxy-collections` | Automerge minor/patch for galaxy-collection via branch, ignoreTests |
| `github>mmalyska/renovate-config:automerge-galaxy-roles` | Automerge for Ansible Galaxy roles |
| `github>mmalyska/renovate-config:generic-regex-manager.json5` | Regex manager for comment-annotated versions in YAML/Dockerfile |
| `github>mmalyska/renovate-config:devcontainer-regex-manager.json5` | Regex manager for `"image":` in `.devcontainer/devcontainer.json` |

---

## Minimal Base Config

For a new repo, start with:

```json5
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>mmalyska/renovate-config"
  ],
  "timezone": "CET",
  "gitAuthor": "renovate-bot <renovate-bot@users.noreply.github.com>"
}
```

This pulls in: `config:base`, dependency dashboard, Docker digest pinning, commit message conventions, PR labels, and semantic commits.

---

## Adding Sub-Presets

Include individual presets to add automerge for specific datasources:

```json5
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>mmalyska/renovate-config",
    "github>mmalyska/renovate-config:automerge-github-actions",
    "github>mmalyska/renovate-config:automerge-terraform-providers"
  ]
}
```

---

## Local Override Pattern

For per-repo rules that don't belong in the shared preset, use local files in `.github/renovate/`:

```json5
// .github/renovate.json5
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>mmalyska/renovate-config",
    "github>mmalyska/renovate-config:automerge-github-actions",
    "local>OWNER/REPO//.github/renovate/autoMerge.json5",
    "local>OWNER/REPO//.github/renovate/groups.json5"
  ],
  "ignorePaths": [".archive/**"],
  "reviewers": ["username"]
}
```

The `local>` prefix references files in the same repo without a network round-trip.

---

## Full home-ops Pattern (Reference)

The `mmalyska/home-ops` repo is the canonical usage example:

```json5
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>mmalyska/renovate-config",
    "github>mmalyska/renovate-config:automerge-github-actions",
    "github>mmalyska/renovate-config:automerge-terraform-providers",
    "local>mmalyska/home-ops//.github/renovate/allowedVersions.json5",
    "local>mmalyska/home-ops//.github/renovate/autoMerge.json5",
    "local>mmalyska/home-ops//.github/renovate/disabledDatasources.json5",
    "local>mmalyska/home-ops//.github/renovate/groups.json5",
    "local>mmalyska/home-ops//.github/renovate/managers.json5",
    "local>mmalyska/home-ops//.github/renovate/customManagers.json5"
  ],
  "gitAuthor": "bendo-bot <126472327+bendo-bot[bot]@users.noreply.github.com>",
  "ignorePaths": [".archive/**", "charts/**"],
  "reviewers": ["mmalyska"]
}
```

---

## Dependency Dashboard

The base preset enables `":dependencyDashboard"`. This creates a GitHub issue titled "Renovate Dashboard" listing all pending updates. To disable:

```json5
{
  "dependencyDashboard": false
}
```

---

## Rate Limiting

The base preset disables rate limiting (`":disableRateLimiting"`). To re-enable for low-traffic repos:

```json5
{
  "prHourlyLimit": 2,
  "prConcurrentLimit": 5
}
```
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/renovate/skills/extending-presets/SKILL.md
grep "name:" ~/projects/claude-plugins/plugins/renovate/skills/extending-presets/SKILL.md | head -1
grep "automerge-docker-digest" ~/projects/claude-plugins/plugins/renovate/skills/extending-presets/SKILL.md
```
Expected: file exists, has `name:` frontmatter, lists `automerge-docker-digest`.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/renovate/skills/extending-presets/SKILL.md
git commit -m "feat(renovate): add extending-presets skill"
```

---

## Task 8: renovate custom-regex-managers skill

**Files:**
- Create: `plugins/renovate/skills/custom-regex-managers/SKILL.md`

**Context:** The `mmalyska/renovate-config` provides two regex manager files: `generic-regex-manager.json5` (for comment-annotated versions in YAML/Dockerfile) and `devcontainer-regex-manager.json5` (for devcontainer.json). This skill explains the annotation patterns and how to add them to YAML/Helm/Ansible files.

The actual source patterns from the repo:
- Generic: `# renovate: datasource=X depName=Y` above a version field
- Generic Docker: `# renovate-docker` + indented `image: name:tag@digest`
- Devcontainer: matches `"image": "name:tag@digest"` in devcontainer.json

- [ ] **Step 1: Define acceptance criteria**

The SKILL.md must show:
- Both regex patterns from `generic-regex-manager.json5`
- The devcontainer pattern from `devcontainer-regex-manager.json5`
- Annotated YAML examples for each pattern
- How to test that Renovate picks up the version

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/renovate/skills/custom-regex-managers/SKILL.md`:

```markdown
---
name: renovate-custom-regex-managers
description: Comment-annotation patterns for Renovate to track versions in YAML, Dockerfile, and devcontainer.json files — patterns from mmalyska/renovate-config
---

# Renovate Custom Regex Managers

## When to Use

Use these annotation patterns when a file contains version strings that Renovate's built-in managers don't detect — typically Helm values files, Ansible task files, raw Dockerfiles with ARG versions, or Kubernetes manifests that pin tool versions.

The patterns are provided by the `generic-regex-manager.json5` and `devcontainer-regex-manager.json5` presets in `mmalyska/renovate-config` (included in the base preset).

---

## Pattern 1: Generic Comment Annotation (YAML / Dockerfile)

Annotate a version field in any `.yaml`, `.yml`, or `Dockerfile` with a comment line directly above it:

```yaml
# renovate: datasource=github-releases depName=sigstore/cosign
cosign_version: v2.2.3
```

```yaml
# renovate: datasource=docker depName=docker.io/bitnami/kubectl
kubectl_image_tag: "1.29.2"
```

```yaml
# renovate: datasource=helm depName=prometheus-community/kube-prometheus-stack versioning=semver
chart_version: "57.2.0"
```

```yaml
# renovate: datasource=terraform-provider depName=hashicorp/aws
aws_provider_version: "~> 5.0"
```

The `versioning` field is optional; defaults to `semver` if omitted.

### versionTemplate for non-standard formats

When the version field has a prefix/suffix around the version number, use `versionTemplate`:

```yaml
# renovate: datasource=github-releases depName=aquasecurity/trivy versionTemplate=v{{version}}
TRIVY_VERSION: 0.50.0
```

### kustomize remote URL pattern

For kustomize remote references like `github.com/dep/dep/v1.0.0/folder`:

```yaml
# renovate-raw: datasource=github-releases depName=owner/repo
bases:
  - github.com/owner/repo/v1.0.0/path/to/base
```

---

## Pattern 2: Docker Image in YAML (with digest)

For YAML files containing `image:` fields that need digest pinning:

```yaml
# renovate-docker
  image: docker.io/cloudflare/cloudflared:2024.1.0@sha256:abc123...
```

```yaml
# renovate-docker
  image: ghcr.io/mmalyska/my-app:main@sha256:abc123...
```

The annotation must be on the line directly above the `image:` field. Renovate will update both the tag and the digest.

---

## Pattern 3: devcontainer.json Image

The `devcontainer-regex-manager.json5` preset matches the `"image"` field in `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/mmalyska/home-ops-devcontainer:main@sha256:abc123..."
}
```

No annotation comment needed — the manager matches the `"image":` key directly.

Renovate will open a PR to update the digest when a new image is pushed.

---

## Checking Your Annotations

To verify Renovate will pick up your annotations, run the Renovate debug command locally (requires a Renovate installation):

```bash
LOG_LEVEL=debug renovate --token $GITHUB_TOKEN --dry-run owner/repo 2>&1 | grep -A2 "customManagers"
```

Or check the Renovate Dashboard issue in the repo after pushing — any unmatched versions will appear as "no update found".

---

## Adding Custom Managers Beyond the Presets

If you need a regex manager the shared presets don't cover, add it in a local override file:

```json5
// .github/renovate/customManagers.json5
{
  "customManagers": [
    {
      "customType": "regex",
      "description": "Track Go toolchain version in .go-version",
      "fileMatch": ["^\\.go-version$"],
      "matchStrings": ["(?<currentValue>.+)"],
      "depNameTemplate": "golang/go",
      "datasourceTemplate": "github-releases",
      "versioningTemplate": "semver-coerced"
    }
  ]
}
```

Reference this in your `renovate.json5`:
```json5
"extends": [
  "github>mmalyska/renovate-config",
  "local>owner/repo//.github/renovate/customManagers.json5"
]
```
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/renovate/skills/custom-regex-managers/SKILL.md
grep "renovate:" ~/projects/claude-plugins/plugins/renovate/skills/custom-regex-managers/SKILL.md | head -3
grep "devcontainer" ~/projects/claude-plugins/plugins/renovate/skills/custom-regex-managers/SKILL.md
```
Expected: file exists, shows annotation patterns, mentions devcontainer.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/renovate/skills/custom-regex-managers/SKILL.md
git commit -m "feat(renovate): add custom-regex-managers skill"
```

---

## Task 9: renovate automerge-rules skill

**Files:**
- Create: `plugins/renovate/skills/automerge-rules/SKILL.md`

**Context:** The `mmalyska/renovate-config` provides five automerge sub-presets. This skill explains when and how to use each one, plus how to write custom automerge rules scoped by file, package name, or datasource — as done in `mmalyska/home-ops/.github/renovate/autoMerge.json5`.

- [ ] **Step 1: Define acceptance criteria**

The SKILL.md must:
- List all 5 automerge sub-presets with their exact packageRule contents
- Explain `automergeType: "branch"` vs `"pr"` and when to use each
- Show `matchFileNames` scoping pattern from home-ops
- Show `ignoreTests` usage and risk
- Show `minimumReleaseAge` for safety

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/renovate/skills/automerge-rules/SKILL.md`:

```markdown
---
name: renovate-automerge-rules
description: Datasource-specific automerge rules — shared presets from mmalyska/renovate-config and per-repo scoping patterns from mmalyska/home-ops
---

# Renovate Automerge Rules

## When to Use

Use this skill when configuring automerge in a `renovate.json5`. It covers the shared presets (extend them directly), how to scope automerge to specific files or packages, and when to use `branch` vs `pr` automerge type.

---

## Shared Automerge Presets

These are provided by `mmalyska/renovate-config`. Extend the ones you need:

### `automerge-docker-digest`
Automerge digest-only updates for all docker images:
```json
{
  "packageRules": [{
    "matchDatasources": ["docker"],
    "automerge": true,
    "automergeType": "branch",
    "matchUpdateTypes": ["digest"],
    "ignoreTests": false
  }]
}
```
Use when: you pin all Docker images to digests and want them to stay current automatically.

### `automerge-github-actions`
Automerge minor/patch/digest for GitHub Actions:
```json
{
  "packageRules": [{
    "matchManagers": ["github-actions"],
    "automerge": true,
    "automergeType": "branch",
    "matchUpdateTypes": ["minor", "patch", "digest"],
    "ignoreTests": true
  }]
}
```
`ignoreTests: true` means Renovate merges directly without waiting for CI — appropriate for Actions where the update itself doesn't affect your code.

### `automerge-terraform-providers`
Automerge minor/patch for Terraform providers:
```json
{
  "packageRules": [{
    "matchDatasources": ["terraform-provider"],
    "automerge": true,
    "automergeType": "branch",
    "matchUpdateTypes": ["minor", "patch"],
    "ignoreTests": false
  }]
}
```

### `automerge-galaxy-collections` / `automerge-galaxy-roles`
Automerge minor/patch for Ansible Galaxy collections and roles:
```json
{
  "packageRules": [{
    "matchDatasources": ["galaxy-collection"],
    "automerge": true,
    "automergeType": "branch",
    "matchUpdateTypes": ["minor", "patch"],
    "ignoreTests": true
  }]
}
```

---

## `automergeType: "branch"` vs `"pr"`

| Type | Behavior | Use when |
|------|----------|---------|
| `"branch"` | Renovate merges directly to base branch if CI passes (or ignoreTests) | Low-risk updates; CI is reliable; prefer fewer PRs |
| `"pr"` | Creates a PR that auto-merges after approval/CI | Higher-risk updates; want review trail; GitHub branch protection required |

For most automerge rules in home-ops-style repos, `"branch"` is preferred.

---

## Per-Repo Scoping Patterns

Use `matchFileNames` to limit automerge to specific directories:

```json5
// .github/renovate/autoMerge.json5
{
  "packageRules": [
    {
      "description": "Auto merge cluster apps (not core)",
      "matchDatasources": ["github-releases", "github-tags", "helm", "docker"],
      "automerge": true,
      "automergeType": "pr",
      "matchUpdateTypes": ["minor", "patch", "digest"],
      "matchFileNames": ["cluster/**", "!cluster/core/**"],
      "ignoreTests": false
    },
    {
      "description": "Auto merge devcontainer digest",
      "matchDatasources": ["docker"],
      "automerge": true,
      "automergeType": "branch",
      "matchUpdateTypes": ["digest"],
      "matchFileNames": [".devcontainer/devcontainer.json"],
      "ignoreTests": true
    }
  ]
}
```

Use `matchPackageNames` to limit to specific packages:

```json5
{
  "packageRules": [
    {
      "description": "Auto merge pre-commit hooks",
      "matchDatasources": ["github-releases", "github-tags"],
      "automerge": true,
      "automergeType": "branch",
      "matchUpdateTypes": ["minor", "patch"],
      "matchPackageNames": [
        "pre-commit/pre-commit-hooks",
        "adrienverge/yamllint"
      ],
      "ignoreTests": true
    }
  ]
}
```

---

## Safety: `minimumReleaseAge`

Add a minimum age before automerging to avoid immediately pulling in a botched release:

```json5
{
  "packageRules": [{
    "matchDatasources": ["github-releases"],
    "automerge": true,
    "automergeType": "branch",
    "matchUpdateTypes": ["minor", "patch"],
    "minimumReleaseAge": "3 days"
  }]
}
```

---

## Never Automerge Major Versions

The base preset does not automerge major versions for any datasource. To explicitly block a datasource from major automerge:

```json5
{
  "packageRules": [{
    "matchDatasources": ["helm"],
    "matchUpdateTypes": ["major"],
    "automerge": false
  }]
}
```
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/renovate/skills/automerge-rules/SKILL.md
grep "automergeType" ~/projects/claude-plugins/plugins/renovate/skills/automerge-rules/SKILL.md | wc -l
grep "matchFileNames" ~/projects/claude-plugins/plugins/renovate/skills/automerge-rules/SKILL.md
```
Expected: file exists, multiple `automergeType` references, contains `matchFileNames`.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/renovate/skills/automerge-rules/SKILL.md
git commit -m "feat(renovate): add automerge-rules skill"
```

---

## Task 10: renovate-auditor agent + README

**Files:**
- Create: `plugins/renovate/agents/renovate-auditor.md`
- Modify: `plugins/renovate/README.md`

**Context:** The renovate-auditor agent proactively checks a repo's Renovate config for consistency with the `mmalyska/renovate-config` conventions. It finds missing presets, incorrect automerge patterns, untracked dependencies (files without annotations), and outdated patterns.

- [ ] **Step 1: Define acceptance criteria**

`renovate-auditor.md` must:
- Have YAML frontmatter with description
- List what it checks (preset usage, automerge, regex coverage, dashboard)
- Show the audit report format

The README update must remove "Coming in Plan 2" and add proper documentation.

- [ ] **Step 2: Create renovate-auditor.md**

Create `~/projects/claude-plugins/plugins/renovate/agents/renovate-auditor.md`:

```markdown
---
description: Audit a repo's Renovate config for consistency with mmalyska/renovate-config conventions. Use PROACTIVELY when writing or reviewing renovate.json5 files.
---

# Renovate Config Auditor

Audit a repository's Renovate configuration for consistency with `mmalyska/renovate-config` conventions. Reports issues, missing presets, and improvement opportunities.

## When to Use

- After writing a new `renovate.json5`
- When reviewing a PR that modifies Renovate config
- When Renovate is not picking up expected updates in a repo
- When asked to "check the renovate config"

## Audit Checklist

### 1. Base Preset

- [ ] Config extends `"github>mmalyska/renovate-config"` (directly or via another preset that includes it)
- [ ] `$schema` is present and points to `https://docs.renovatebot.com/renovate-schema.json`
- [ ] `timezone` is set (default: `"CET"`)
- [ ] `gitAuthor` is set if using a bot identity

### 2. Dependency Dashboard

- [ ] Dashboard is enabled (included in base preset; verify not explicitly disabled)
- [ ] `dependencyDashboardTitle` set if custom title needed

### 3. Automerge Rules

For each datasource present in the repo:

| If repo contains | Recommend extending |
|----------------|-------------------|
| GitHub Actions workflows | `automerge-github-actions` |
| Terraform provider configs | `automerge-terraform-providers` |
| Ansible Galaxy deps | `automerge-galaxy-collections` |
| Docker digests | `automerge-docker-digest` |
| devcontainer image | Local rule with `matchFileNames: [".devcontainer/devcontainer.json"]` |

### 4. Regex Manager Coverage

Check if these file types exist in the repo without Renovate annotations:

- `.yaml`/`.yml` files with `image:` lines → need `# renovate-docker` annotation
- `.yaml`/`.yml` files with tool versions → need `# renovate: datasource=X depName=Y` annotation
- `.devcontainer/devcontainer.json` with `"image":` → covered by devcontainer-regex-manager
- `Dockerfile` with `ARG *_VERSION=` → need annotation

### 5. Local Override Structure

If the repo has local overrides, check they follow the `local>owner/repo//.github/renovate/*.json5` pattern and are referenced in the main config.

### 6. ignorePaths

Verify `ignorePaths` excludes archived or vendored directories (`.archive/**`, `charts/**`) that should not be updated.

## Audit Report Format

```
RENOVATE AUDIT — owner/repo

Base config: .github/renovate.json5

✓ PASS  Base preset: github>mmalyska/renovate-config extended
✓ PASS  Schema present
✓ PASS  Dependency dashboard enabled
⚠ WARN  Timezone not set (defaulting to UTC, expected CET)
✗ FAIL  No automerge-github-actions preset — 3 GitHub Actions workflows found

Missing annotations:
  cluster/apps/networking/values.yaml:12 — image: docker.io/traefik:v3.0.0
    → Add: # renovate-docker annotation above the image line
  cluster/apps/monitoring/helm-release.yaml:8 — chart_version: "45.0.0"
    → Add: # renovate: datasource=helm depName=prometheus-community/kube-prometheus-stack

Recommendations:
  1. Add "github>mmalyska/renovate-config:automerge-github-actions" to extends
  2. Add # renovate-docker annotation to 2 YAML image fields
  3. Set timezone: "CET" in renovate.json5
```

## How to Run

The user should provide the path to the repo or confirm the current repo. Then:

1. Read the `renovate.json5` (or `renovate.json`, `.github/renovate.json5`)
2. Read local override files if referenced
3. Scan the repo for files that need annotations
4. Run through the audit checklist
5. Output the audit report
```

- [ ] **Step 3: Update renovate README**

Replace the full content of `~/projects/claude-plugins/plugins/renovate/README.md` with:

```markdown
# renovate

Renovate config authoring for Claude Code — skills and agent for `mmalyska/renovate-config` presets.

## Skills

- `extending-presets` — How to extend `mmalyska/renovate-config` in a repo's `renovate.json5`, including all 11 available sub-presets and the local override pattern
- `custom-regex-managers` — Comment-annotation patterns for tracking versions in YAML, Dockerfile, and devcontainer.json
- `automerge-rules` — Datasource-specific automerge configuration with branch/PR modes and file scoping

## Agent

- `renovate-auditor` — Audits a repo's Renovate config for consistency with `mmalyska/renovate-config` conventions

## Install

```sh
claude plugin install renovate@mmalyska-claude-plugins
```

## Usage

Skills are available automatically after installation. The `renovate-auditor` agent is invoked via the Agent tool:

```
Use the renovate-auditor agent to audit this repo's Renovate config.
```
```

- [ ] **Step 4: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/renovate/agents/renovate-auditor.md
grep "Audit Checklist" ~/projects/claude-plugins/plugins/renovate/agents/renovate-auditor.md
grep "Coming in Plan" ~/projects/claude-plugins/plugins/renovate/README.md && echo "STILL PRESENT - ERROR" || echo "OK - removed"
```
Expected: agent file exists, has checklist, README no longer says "Coming in Plan".

- [ ] **Step 5: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/renovate/agents/renovate-auditor.md plugins/renovate/README.md
git commit -m "feat(renovate): add renovate-auditor agent and update README"
```

---

## Task 11: devcontainer ghcr-image-pipeline skill

**Files:**
- Create: `plugins/devcontainer/skills/ghcr-image-pipeline/SKILL.md`

**Context:** The `mmalyska/home-ops` repo publishes a custom devcontainer image to GHCR using the `devcontainers/ci@v0.3` action. This skill documents the full workflow pattern — Docker login, `docker/metadata-action` for tagging, the tag transformation step (stripping the registry prefix for the devcontainers/ci format), `cacheFrom`, push filter, and the post-build Renovate trigger.

Key pattern from `.github/workflows/devcontainer-publish.yaml`:
- Image lives under `.github/.devcontainer/` (not root `.devcontainer/`)
- Uses `devcontainers/ci` action with `subFolder: .github`
- Tags derived from `docker/metadata-action`, then stripped to just the tag portion
- Renovate is triggered after a successful build via a reusable workflow

- [ ] **Step 1: Define acceptance criteria**

The SKILL.md must:
- Show the complete workflow file structure
- Explain each step with its purpose
- Explain the tag transformation step (why it's needed)
- Show how to reference the image in `.devcontainer/devcontainer.json`
- Explain the Renovate trigger step

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/devcontainer/skills/ghcr-image-pipeline/SKILL.md`:

```markdown
---
name: devcontainer-ghcr-image-pipeline
description: GitHub Actions workflow for building and publishing a custom devcontainer image to GHCR using devcontainers/ci, with tag transformation and Renovate trigger — pattern from mmalyska/home-ops
---

# Devcontainer GHCR Image Pipeline

## When to Use

Use this skill when setting up a GitHub Actions workflow to automatically build and publish a custom devcontainer image to GHCR (`ghcr.io`). This is the pattern used in `mmalyska/home-ops`.

---

## Directory Layout

The devcontainer definition lives under `.github/.devcontainer/` (not the root `.devcontainer/`). This separates the repo's development environment from the published image's source:

```
.github/
├── .devcontainer/
│   ├── devcontainer.json    ← defines the image to build
│   └── Dockerfile           ← image definition (if custom build)
└── workflows/
    └── devcontainer-publish.yaml
.devcontainer/
    └── devcontainer.json    ← references the published ghcr.io image
```

---

## Complete Workflow

Create `.github/workflows/devcontainer-publish.yaml`:

```yaml
name: Devcontainer
on:
  workflow_dispatch:
    inputs:
      confirm:
        description: 'Type "yes" to confirm manual publish'
        required: true
        default: "no"
  pull_request:
    paths:
      - ".github/.devcontainer/**"
  push:
    branches:
      - "main"
    paths:
      - ".github/.devcontainer/**"

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: OWNER/REPO-devcontainer   # ← replace with actual owner/repo

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        # renovate: datasource=github-releases depName=docker/setup-buildx-action
        uses: docker/setup-buildx-action@v3

      - name: Log into registry
        if: github.event_name != 'pull_request'
        # renovate: datasource=github-releases depName=docker/login-action
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract Docker metadata
        id: meta
        # renovate: datasource=github-releases depName=docker/metadata-action
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

      # The devcontainers/ci action needs just the tag portion, not the full image:tag string
      - name: Strip registry prefix from tags
        id: dcmeta
        run: |
          prefix="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}"
          input_list="$DOCKER_METADATA_OUTPUT_TAGS"
          result_list="${input_list//${prefix}:/}"
          echo "tags=$result_list" >> "$GITHUB_OUTPUT"

      - name: Build and push devcontainer image
        # renovate: datasource=github-releases depName=devcontainers/ci
        uses: devcontainers/ci@v0.3
        with:
          imageName: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          imageTag: ${{ steps.dcmeta.outputs.tags }}
          cacheFrom: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          push: filter
          refFilterForPush: refs/heads/main
          eventFilterForPush: push
          subFolder: .github   # ← points to .github/.devcontainer/

  renovate:
    name: Trigger Renovate
    needs: build
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: OWNER/REPO/.github/workflows/scheduled-renovate.yaml@main
    secrets: inherit
```

---

## Key Concepts

### Tag Transformation Step

`docker/metadata-action` outputs tags as `ghcr.io/owner/repo:main`, `ghcr.io/owner/repo:sha-abc123`, etc. The `devcontainers/ci` action expects **only the tag portion** (`main`, `sha-abc123`). The strip step removes the `ghcr.io/owner/repo:` prefix.

### Push Filter

The `push: filter` + `refFilterForPush: refs/heads/main` combination means:
- On PRs: the image is built but NOT pushed (validates the build)
- On push to main: the image is built AND pushed

### cacheFrom

```yaml
cacheFrom: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
```

Pulls the previously published image as a layer cache, dramatically speeding up builds.

### Renovate Trigger

After a new image is pushed, calling the `scheduled-renovate.yaml` workflow immediately causes Renovate to detect the new digest and open an update PR for `.devcontainer/devcontainer.json`. Without this step, Renovate waits for its next scheduled run.

---

## Referencing the Published Image

In `.devcontainer/devcontainer.json` (the developer-facing file):

```json
{
  "name": "my-project",
  "image": "ghcr.io/owner/repo-devcontainer:main@sha256:abc123..."
}
```

The digest (`@sha256:...`) ensures reproducibility. Renovate will keep this updated automatically via the `devcontainer-regex-manager` preset.

---

## Required Repository Settings

1. **Packages permission**: The workflow uses `packages: write`. The package must be connected to the repo or the GITHUB_TOKEN must have explicit package access.
2. **Branch protection**: If main is protected, ensure the Renovate bot is allowed to push directly (for `automergeType: "branch"`).
3. **Reusable workflow**: The Renovate trigger step assumes `scheduled-renovate.yaml` exists. Replace with `workflow_dispatch` on the Renovate app if using the cloud service.
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/devcontainer/skills/ghcr-image-pipeline/SKILL.md
grep "devcontainers/ci" ~/projects/claude-plugins/plugins/devcontainer/skills/ghcr-image-pipeline/SKILL.md
grep "subFolder" ~/projects/claude-plugins/plugins/devcontainer/skills/ghcr-image-pipeline/SKILL.md
```
Expected: file exists, contains `devcontainers/ci`, mentions `subFolder`.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/devcontainer/skills/ghcr-image-pipeline/SKILL.md
git commit -m "feat(devcontainer): add ghcr-image-pipeline skill"
```

---

## Task 12: devcontainer secrets-injection skill

**Files:**
- Create: `plugins/devcontainer/skills/secrets-injection/SKILL.md`

**Context:** The `mmalyska/home-ops` devcontainer uses two parallel secret injection mechanisms: a `"secrets"` block in `devcontainer.json` (for GitHub Codespaces) and a `devcontainer.env` file (for local VS Code). Secrets include Terraform Cloud token, Bitwarden Secrets Manager token, GitHub token, and WireGuard VPN credentials. The `runArgs` passes `--env-file` and adds `--cap-add=NET_ADMIN` for WireGuard.

Exact structure from `.devcontainer/devcontainer.json` and `.devcontainer/devcontainer.env.sample`.

- [ ] **Step 1: Define acceptance criteria**

The SKILL.md must:
- Show the `"secrets"` block pattern (Codespaces)
- Show the `devcontainer.env` + `--env-file` pattern (local)
- Show the `initializeCommand` to auto-create env from sample
- Show the WireGuard capabilities (`--cap-add=NET_ADMIN`, `--device=/dev/net/tun`)
- Show `.gitignore` entry for `devcontainer.env`
- Show the `devcontainer.env.sample` format

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/devcontainer/skills/secrets-injection/SKILL.md`:

```markdown
---
name: devcontainer-secrets-injection
description: Two-mechanism secret injection for devcontainers — Codespaces secrets block and local devcontainer.env file, with WireGuard VPN capabilities — pattern from mmalyska/home-ops
---

# Devcontainer Secrets Injection

## When to Use

Use this skill when a devcontainer needs access to credentials (API tokens, VPN keys, etc.) in both GitHub Codespaces and local VS Code Dev Containers. The pattern uses two parallel mechanisms that work transparently in each environment.

---

## Mechanism 1: Codespaces — `"secrets"` block

In GitHub Codespaces, secrets are injected as environment variables from the repository's Codespaces secrets (Settings > Secrets and variables > Codespaces).

Declare each secret in `devcontainer.json`:

```json
{
  "secrets": {
    "TERRAFORM_TOKEN": {
      "description": "Token to access Terraform Cloud."
    },
    "BWS_ACCESS_TOKEN": {
      "description": "Token to access Bitwarden Secrets Manager API."
    },
    "GITHUB_TOKEN": {
      "description": "Personal access token for GitHub API."
    },
    "WG_PRIVATE_KEY": {
      "description": "WireGuard client private key for home lab VPN."
    },
    "WG_ENDPOINT": {
      "description": "WireGuard server endpoint (host:port)."
    }
  }
}
```

The `description` fields appear in the Codespaces UI when a secret is not set.

---

## Mechanism 2: Local — `devcontainer.env` file

For local VS Code, secrets live in a gitignored `.devcontainer/devcontainer.env` file and are passed to the container via `--env-file`.

### `.devcontainer/devcontainer.env.sample`

Commit a sample file with commented-out keys and no values:

```bash
# Local development secrets — copy this file to devcontainer.env and fill in the values.
# devcontainer.env is gitignored. In GitHub Codespaces, set these as repository secrets instead.
#
# TERRAFORM_TOKEN=    # Terraform Cloud token
# BWS_ACCESS_TOKEN=   # Bitwarden Secrets Manager token
# GITHUB_TOKEN=       # GitHub PAT (also used as HOMEBREW_GITHUB_API_TOKEN)
# WG_PRIVATE_KEY=     # WireGuard client private key
# WG_ENDPOINT=        # WireGuard server endpoint host:port (e.g. vpn.example.com:51820)
```

**Never commit actual values.** All lines should be commented out in the sample.

### `.gitignore`

```gitignore
.devcontainer/devcontainer.env
```

### `runArgs` in `devcontainer.json`

```json
{
  "runArgs": ["--env-file", ".devcontainer/devcontainer.env"]
}
```

### `initializeCommand` — auto-create env from sample

```json
{
  "initializeCommand": "test -f .devcontainer/devcontainer.env || cp .devcontainer/devcontainer.env.sample .devcontainer/devcontainer.env"
}
```

This runs before the container starts and creates `devcontainer.env` from the sample if it doesn't exist. The developer then fills in the actual values without creating a blank file from scratch.

---

## WireGuard VPN Capabilities

If the container needs to establish a WireGuard VPN tunnel (e.g. to reach a homelab), add network capabilities to `runArgs`:

```json
{
  "runArgs": [
    "--env-file", ".devcontainer/devcontainer.env",
    "--cap-add=NET_ADMIN",
    "--device=/dev/net/tun"
  ]
}
```

- `--cap-add=NET_ADMIN`: allows the container to manage network interfaces
- `--device=/dev/net/tun`: exposes the TUN device for tunnel creation

**Note:** `--device=/dev/net/tun` requires the host to have `/dev/net/tun` available. This is always true on Linux hosts; on macOS with Docker Desktop it is also available. This flag is not needed in GitHub Codespaces (VPN is handled at the host level).

---

## Complete `devcontainer.json` Example

```json
{
  "name": "my-project",
  "image": "ghcr.io/owner/repo-devcontainer:main@sha256:abc123...",
  "secrets": {
    "TERRAFORM_TOKEN": {
      "description": "Token to access Terraform Cloud."
    },
    "BWS_ACCESS_TOKEN": {
      "description": "Token to access Bitwarden Secrets Manager API."
    },
    "GITHUB_TOKEN": {
      "description": "Personal access token for GitHub API."
    },
    "WG_PRIVATE_KEY": {
      "description": "WireGuard client private key."
    },
    "WG_ENDPOINT": {
      "description": "WireGuard server endpoint host:port."
    }
  },
  "runArgs": [
    "--env-file", ".devcontainer/devcontainer.env",
    "--cap-add=NET_ADMIN",
    "--device=/dev/net/tun"
  ],
  "initializeCommand": "test -f .devcontainer/devcontainer.env || cp .devcontainer/devcontainer.env.sample .devcontainer/devcontainer.env",
  "onCreateCommand": "bash .devcontainer/scripts/onCreateCommand.sh ${containerWorkspaceFolder}",
  "remoteUser": "vscode",
  "containerUser": "vscode"
}
```

---

## Codespaces vs Local Behavior

| | Codespaces | Local VS Code |
|-|-----------|--------------|
| Secret source | Repository Codespaces secrets | `.devcontainer/devcontainer.env` |
| Mechanism | `"secrets"` block | `--env-file` in `runArgs` |
| `devcontainer.env` | Not read (env injected by Codespaces) | Must exist and be filled in |
| WireGuard `--device` | Not needed | Works on Linux/macOS hosts |

When both mechanisms are present, Codespaces uses the `"secrets"` block and ignores the `--env-file` (since `devcontainer.env` doesn't exist in the Codespaces workspace). Local VS Code uses the `--env-file` and ignores the `"secrets"` block.
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/devcontainer/skills/secrets-injection/SKILL.md
grep "devcontainer.env" ~/projects/claude-plugins/plugins/devcontainer/skills/secrets-injection/SKILL.md | wc -l
grep "NET_ADMIN" ~/projects/claude-plugins/plugins/devcontainer/skills/secrets-injection/SKILL.md
```
Expected: file exists, multiple `devcontainer.env` references, contains `NET_ADMIN`.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/devcontainer/skills/secrets-injection/SKILL.md
git commit -m "feat(devcontainer): add secrets-injection skill"
```

---

## Task 13: devcontainer renovate-digest-pinning skill

**Files:**
- Create: `plugins/devcontainer/skills/renovate-digest-pinning/SKILL.md`

**Context:** The devcontainer image in `.devcontainer/devcontainer.json` should be pinned to a digest (`@sha256:...`) and kept current by Renovate. The `mmalyska/renovate-config:devcontainer-regex-manager.json5` preset handles the detection. The `mmalyska/home-ops` repo has a per-file automerge rule scoped to `.devcontainer/devcontainer.json`. This skill ties it together.

- [ ] **Step 1: Define acceptance criteria**

The SKILL.md must:
- Show how to write the `"image"` field with a pinned digest
- Show which preset to extend for detection
- Show the per-file automerge rule
- Show how to find the current digest from GHCR
- Reference the `ghcr-image-pipeline` skill

- [ ] **Step 2: Create the file**

Create `~/projects/claude-plugins/plugins/devcontainer/skills/renovate-digest-pinning/SKILL.md`:

```markdown
---
name: devcontainer-renovate-digest-pinning
description: How to pin a devcontainer image to a digest and keep it automatically updated by Renovate — using mmalyska/renovate-config devcontainer preset and per-file automerge rule
---

# Devcontainer Renovate Digest Pinning

## When to Use

Use this skill when setting up automatic digest updates for a devcontainer image. It covers:
1. Writing the `"image"` field with a pinned digest
2. The Renovate preset that detects the digest
3. The automerge rule to merge digest updates without review

For the image build pipeline that publishes the image, see the `ghcr-image-pipeline` skill.

---

## Step 1: Pin the Image to a Digest

In `.devcontainer/devcontainer.json`, write the `"image"` field as `name:tag@sha256:digest`:

```json
{
  "image": "ghcr.io/owner/repo-devcontainer:main@sha256:190379025cb9f2537f50b0ac9dff75207e62c1a2d986b251eea4f1b8d0966b5a"
}
```

**Why pin to a digest?** Tags are mutable — `main` can point to a different image layer after a rebuild. Pinning to a digest guarantees reproducibility and lets Renovate detect exactly when a new image was published.

---

## Step 2: Get the Current Digest

When first setting up or after a manual publish:

```bash
# Pull the image and show its digest
docker pull ghcr.io/owner/repo-devcontainer:main
docker inspect ghcr.io/owner/repo-devcontainer:main --format '{{index .RepoDigests 0}}'
# Output: ghcr.io/owner/repo-devcontainer@sha256:abc123...

# Or use crane (no pull required)
crane digest ghcr.io/owner/repo-devcontainer:main
```

Use the `sha256:...` portion as the digest in the image reference.

---

## Step 3: Enable the Renovate Preset

Ensure your `renovate.json5` (or `renovate.json`) includes the base preset or the devcontainer-specific preset:

```json5
{
  "extends": [
    "github>mmalyska/renovate-config"   // includes devcontainer-regex-manager
  ]
}
```

The `devcontainer-regex-manager.json5` preset matches:

```json5
// Pattern it matches in devcontainer.json:
"image": "name:tag@sha256:digest"
// or (without digest):
"image": "name:tag"
```

---

## Step 4: Add the Per-File Automerge Rule

Add a `packageRule` scoped to `.devcontainer/devcontainer.json` so digest updates merge automatically without requiring review:

```json5
// .github/renovate/autoMerge.json5 (or inline in renovate.json5)
{
  "packageRules": [
    {
      "description": "Auto merge devcontainer image digest updates",
      "matchDatasources": ["docker"],
      "automerge": true,
      "automergeType": "branch",
      "matchUpdateTypes": ["digest"],
      "matchFileNames": [".devcontainer/devcontainer.json"],
      "ignoreTests": true
    }
  ]
}
```

`ignoreTests: true` is appropriate here because:
- The update is a digest change (same tag, new build)
- The devcontainer image change doesn't affect CI test results
- The purpose is purely to stay current with the latest published image

---

## Step 5: Trigger Renovate After Image Build

If using the `ghcr-image-pipeline` workflow, add a Renovate trigger job after the build:

```yaml
renovate:
  name: Trigger Renovate
  needs: build
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  uses: OWNER/REPO/.github/workflows/scheduled-renovate.yaml@main
  secrets: inherit
```

This immediately triggers Renovate to detect the new digest and open an update PR, rather than waiting for the next scheduled run.

---

## How It Works End-to-End

```
1. Push to main (or merge a PR changing .github/.devcontainer/)
   ↓
2. devcontainer-publish.yaml runs
   ↓
3. New image published to ghcr.io/owner/repo:main (new digest)
   ↓
4. Renovate triggered by post-build job
   ↓
5. Renovate detects the digest changed in .devcontainer/devcontainer.json
   ↓
6. Renovate opens/updates a PR with new digest
   ↓
7. automergeType: "branch" merges it automatically
   ↓
8. .devcontainer/devcontainer.json now pinned to the new digest ✓
```
```

- [ ] **Step 3: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/devcontainer/skills/renovate-digest-pinning/SKILL.md
grep "matchFileNames" ~/projects/claude-plugins/plugins/devcontainer/skills/renovate-digest-pinning/SKILL.md
grep "sha256" ~/projects/claude-plugins/plugins/devcontainer/skills/renovate-digest-pinning/SKILL.md
```
Expected: file exists, contains `matchFileNames`, contains `sha256`.

- [ ] **Step 4: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/devcontainer/skills/renovate-digest-pinning/SKILL.md
git commit -m "feat(devcontainer): add renovate-digest-pinning skill"
```

---

## Task 14: devcontainer-auditor agent + README

**Files:**
- Create: `plugins/devcontainer/agents/devcontainer-auditor.md`
- Modify: `plugins/devcontainer/README.md`

**Context:** The devcontainer-auditor agent checks a repo's devcontainer setup for common issues: unpinned images (no digest), missing secrets declarations, missing lifecycle hooks, and missing Renovate integration.

- [ ] **Step 1: Define acceptance criteria**

`devcontainer-auditor.md` must:
- Have frontmatter with description
- Check for: image digest pinning, secrets block, devcontainer.env.sample, Renovate setup, lifecycle hooks
- Show the audit report format

The README update must remove "Coming in Plan 2" and document the skills and agent.

- [ ] **Step 2: Create devcontainer-auditor.md**

Create `~/projects/claude-plugins/plugins/devcontainer/agents/devcontainer-auditor.md`:

```markdown
---
description: Audit a repo's devcontainer configuration for unpinned images, missing secrets declarations, and missing Renovate integration. Use PROACTIVELY when writing or reviewing devcontainer.json.
---

# Devcontainer Config Auditor

Audit a repository's devcontainer setup for best-practice compliance — digest pinning, secret management, lifecycle hooks, and Renovate integration.

## When to Use

- After creating or modifying `.devcontainer/devcontainer.json`
- When reviewing a PR that touches devcontainer configuration
- When a devcontainer is broken or has unexpected behavior
- When asked to "check the devcontainer config"

## Audit Checklist

### 1. Image Pinning

- [ ] The `"image"` field includes a digest (`@sha256:...`)
- [ ] The digest is not `sha256:` followed by zeroes or placeholder text
- [ ] Tag is meaningful (e.g. `main`, `latest`, a version) not just a digest with no tag

**Finding:** If image has no digest — flag as HIGH. Tag-only images rebuild silently when the upstream tag is updated, causing non-reproducible environments.

### 2. Secrets Management

- [ ] All required credentials have entries in the `"secrets"` block (for Codespaces)
- [ ] `.devcontainer/devcontainer.env.sample` exists with commented keys
- [ ] `.devcontainer/devcontainer.env` is in `.gitignore`
- [ ] `runArgs` includes `--env-file .devcontainer/devcontainer.env` (for local)
- [ ] `initializeCommand` creates `devcontainer.env` from sample if missing

**Finding:** Missing `"secrets"` block — MEDIUM. Missing `devcontainer.env.sample` — HIGH (developers won't know what secrets are needed). `devcontainer.env` not in `.gitignore` — CRITICAL (would leak credentials).

### 3. WireGuard Capabilities (if applicable)

If the container uses WireGuard:
- [ ] `--cap-add=NET_ADMIN` in `runArgs`
- [ ] `--device=/dev/net/tun` in `runArgs`

### 4. Lifecycle Hooks

Check whether these lifecycle script hooks are appropriate for the repo:
- [ ] `initializeCommand` — environment setup that must run before container starts
- [ ] `onCreateCommand` — one-time setup after container is created
- [ ] `updateContentCommand` — runs after a code update (e.g. install deps)
- [ ] `postStartCommand` — runs every time the container starts

**Finding:** If significant setup logic is in `postStartCommand` that should only run once — suggest moving to `onCreateCommand`.

### 5. Renovate Integration

- [ ] `renovate.json5` extends `github>mmalyska/renovate-config` (includes devcontainer-regex-manager)
- [ ] A `packageRule` with `matchFileNames: [".devcontainer/devcontainer.json"]` exists for digest automerge
- [ ] The image build workflow triggers Renovate after publishing (if using a custom image)

**Finding:** Missing Renovate integration — MEDIUM. The digest will become stale and the environment will drift.

### 6. User Identity

- [ ] `"remoteUser"` and `"containerUser"` are set (typically `"vscode"`)
- [ ] Correct permissions for the user to access mounted files

## Audit Report Format

```
DEVCONTAINER AUDIT — owner/repo

Config: .devcontainer/devcontainer.json

✓ PASS  Image pinned to digest: ghcr.io/owner/repo-devcontainer:main@sha256:abc123
✓ PASS  Secrets block present (5 secrets declared)
✓ PASS  devcontainer.env.sample exists
✓ PASS  devcontainer.env in .gitignore
⚠ WARN  No updateContentCommand — consider adding dep install on content update
✗ FAIL  No Renovate automerge rule for .devcontainer/devcontainer.json
✗ FAIL  devcontainer.env.sample not found in repo

Required actions (FAIL):
  1. Add packageRule with matchFileNames: [".devcontainer/devcontainer.json"] to renovate config
     (see renovate-digest-pinning skill)
  2. Create .devcontainer/devcontainer.env.sample with commented secret keys
     (see secrets-injection skill)

Suggestions (WARN):
  1. Add updateContentCommand: "bash .devcontainer/scripts/updateContentCommand.sh"
```

## How to Run

1. Read `.devcontainer/devcontainer.json`
2. Check for `.devcontainer/devcontainer.env.sample`
3. Check `.gitignore` for `devcontainer.env` entry
4. Read `renovate.json5` for Renovate integration
5. Run through the audit checklist
6. Output the audit report
```

- [ ] **Step 3: Update devcontainer README**

Replace the full content of `~/projects/claude-plugins/plugins/devcontainer/README.md` with:

```markdown
# devcontainer

Dev container setup skills for Claude Code — GHCR image pipelines, secrets injection, and Renovate digest pinning.

## Skills

- `ghcr-image-pipeline` — GitHub Actions workflow for building and publishing a custom devcontainer image to GHCR using `devcontainers/ci`, with tag transformation and Renovate trigger
- `secrets-injection` — Two-mechanism secret injection: Codespaces `"secrets"` block and local `devcontainer.env` file, with WireGuard VPN capabilities
- `renovate-digest-pinning` — How to pin a devcontainer image to a digest and keep it automatically updated by Renovate

## Agent

- `devcontainer-auditor` — Audits a repo's devcontainer configuration for unpinned images, missing secrets, and missing Renovate integration

## Install

```sh
claude plugin install devcontainer@mmalyska-claude-plugins
```

## Usage

Skills are available automatically after installation. The `devcontainer-auditor` agent is invoked via the Agent tool:

```
Use the devcontainer-auditor agent to audit this repo's devcontainer config.
```

Skills can be loaded on demand for specific tasks:

```
Use the ghcr-image-pipeline skill to set up a GHCR build pipeline for this repo's devcontainer.
```
```

- [ ] **Step 4: Verify**

```bash
ls -la ~/projects/claude-plugins/plugins/devcontainer/agents/devcontainer-auditor.md
grep "Audit Checklist" ~/projects/claude-plugins/plugins/devcontainer/agents/devcontainer-auditor.md
grep "Coming in Plan" ~/projects/claude-plugins/plugins/devcontainer/README.md && echo "STILL PRESENT - ERROR" || echo "OK - removed"
```
Expected: agent file exists with checklist, README no longer says "Coming in Plan".

- [ ] **Step 5: Commit**

```bash
cd ~/projects/claude-plugins
git add plugins/devcontainer/agents/devcontainer-auditor.md plugins/devcontainer/README.md
git commit -m "feat(devcontainer): add devcontainer-auditor agent and update README"
```

---

## What's Next

After all 14 tasks are complete:

1. Push to GitHub: `cd ~/projects/claude-plugins && git push origin main`
2. `claude plugin update` (or reinstall) to pick up the new commands, skills, and agents
3. Verify the new commands appear: `/spec`, `/build`, `/test`, `/review`, `/simplify`, `/ship`
4. Verify the skills load: `Use the renovate-auditor agent to...`
5. Proceed to migration cleanup: remove migrated files from chezmoi dotfiles (see Plan 1 spec Section 3)
