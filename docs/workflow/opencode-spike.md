# OpenCode spike (experimental, documentation only)

Status: **not implemented, no installer.** `ai_opencode` is a data flag (default `false`, prompt text
`Enable OpenCode (experimental, not implemented)`). Setting it to `true` changes nothing except one informational
line in `ai-workflow-doctor` (`spike not implemented`). It installs nothing, writes no configuration and is not read by
any template or installer; `tests/ai/test_opencode_flag.sh` proves that. An installer needs a separate decision after this
spike has been executed and its evidence reviewed.

The checklist mirrors `docs/workflow/compatibility.md#opencode-manual-path-and-future-spike` in `mmalyska/claude-plugins`
at the accepted revision (`acceptance.md`). `claude-plugins` owns the workflow contract; this repository would only distribute it.

## What is known today (read-only, not a spike result)

| Fact | Source |
| --- | --- |
| Detected version `opencode v2.2.0` (Homebrew), same as in `evidence/T00-baseline.md` | `opencode --version` |
| Subcommands relevant to a later spike: `plugin`, `mcp`, `agents` and `config` under `debug`, `session`, `run`, `service` | `opencode --help`, `opencode debug --help` |
| `opencode debug paths` / `debug config` exist to list the global config, data, cache and state locations and the configuration sources | `opencode debug --help` |
| `--auto` auto-approves permissions that are not explicitly denied: never use it in a spike run | `opencode --help` |

Nothing else about OpenCode is claimed here. Each item below is **unchecked on purpose**: it is deferred, not done, and is
`NOT RUN` until a pinned trial produces evidence.

## Preconditions for the trial

- A disposable HOME and disposable repository; do not point it at `~/.config/opencode` or real projects.
- Pin and record: OpenCode version (start from `v2.2.0`), OS, configuration sources (`opencode debug config`), the
  `claude-plugins` revision from `acceptance.md`.
- No model credentials in the evidence; no `--auto`.
- The trial is done by one session (SOLO). It does not start another harness or orchestrator.

## Checklist

- [ ] **Version pin.** Record release, source revision, OS and configuration; read the version-specific official interfaces instead of copying another host's schema.
- [ ] **Instructions.** Does OpenCode load the shared `AGENTS.md`? Order, precedence and conflict behaviour; compare the resulting policy with Claude Code and Codex.
- [ ] **Skills.** Discovery, metadata and names; access to packaged resources after a fresh install and a reinstall; how command inputs map without duplicating skill bodies.
- [ ] **Permissions and hooks.** Permission semantics, tool limits, which hooks really exist. Without a hook: procedural preflight and a disclosure of the enforcement limit (the worktree-first guard is a Claude hook today).
- [ ] **Subagents / teams.** Is anything exposed, and how is authorization mapped? Absence must be recorded explicitly; actor tests need explicit HANDOFF, PARALLEL or REVIEW scope.
- [ ] **Worktrees.** Creation and reuse, writer ownership, denied creation, dirty primary checkout, on disposable repositories; no reset or cleanup bypass.
- [ ] **Installation through dotfiles.** How would plugins or skills be installed (`opencode plugin`, files, or a manual path) and would that be idempotent, soft-failing and status-reporting like `100-claude-plugins` / `110-codex-plugins`? Which state file and which `entryState` key? Would `ai_opencode=false` skip cleanly? Answer only from the trial, then decide.
- [ ] **Scenarios.** QUICK + SOLO; STANDARD + HANDOFF; an authorized REVIEW including a missing reviewer, an unassigned receiver and a stale base.
- [ ] **Evidence.** Inputs, actual actions and outputs, pass/fail tied to versions, plugin SHA and host state; static preparation kept apart from live results; every skipped check as `NOT RUN` with its reason.

## Exit criteria for turning the spike into an installer

All of the following, each as a separate reviewed change:

1. The checklist above executed with evidence committed under `docs/workflow/evidence/`.
2. A decision that the manual path is not enough.
3. An installer following the existing contract: soft-fail, idempotent, no uninstall, status file, `run_onchange_` fingerprint, a stub-based test in layer A and a native test in layer B.
4. `.chezmoiignore` and Windows/macOS coverage decided explicitly.

Until then the manual path from `claude-plugins` is the supported one.
