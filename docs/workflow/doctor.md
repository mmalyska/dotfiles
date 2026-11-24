# `ai-workflow-doctor`

Read-only report on the AI workflow installers, installed by chezmoi to `~/.local/bin/ai-workflow-doctor`.
**`~/.local/bin` must be on `PATH`.**

```sh
ai-workflow-doctor            # report, always exit 0
ai-workflow-doctor --strict   # exit 1 on DRIFT, MISSING, a pending upgrade or an installer result of "partial"
ai-workflow-doctor --quiet    # nothing when all is well, else one line per thing to do; always exit 0
ai-workflow-doctor --hook     # the same as the JSON a Claude Code SessionStart hook shows; always exit 0
```

It reads the installer status files (`~/.local/state/ai-workflow/<harness>.status`), the marketplace pin (Claude: `HEAD` of the
marketplace checkout; Codex: `ref` in `config.toml`) and `claude|codex plugin list --json`. It never installs, adds or updates anything.
`skipped` (CLI missing or `ai_*=false`) is not an error.

When an installer ended `partial` it **prints** the commands that re-run that one installer; run them yourself:

```sh
chezmoi state delete --bucket=entryState --key="<destDir>/.chezmoiscripts/ai/<nn>-<harness>-plugins.sh"
chezmoi apply
```

Only that script runs again. Do not use `delete-bucket` or `state reset`. Nothing is retried automatically.

With `ai_opencode=true` the report adds one informational line, `spike not implemented`; OpenCode is experimental, nothing is
installed for it and it never affects `--strict` ([opencode-spike.md](opencode-spike.md)).

## Pending upgrades and the session check

After a pin pull request is merged, three things still need you, in this order. The doctor reports each one, in the full
report (section `[pending]`) and in `--quiet`/`--hook`:

1. **Merged upstream, not pulled**: the source's remote has a newer `accepted_sha`. Run `chezmoi git pull`, read `chezmoi diff`.
2. **Pulled, not applied**: the source's `accepted_sha` is not the one this host runs. Run `AI_WORKFLOW_UPGRADE=1 chezmoi apply`.
3. **Plugins behind the marketplace checkout** (Claude): an installed plugin has an older version than the checkout. Run
   `claude plugin update <name>@mmalyska-claude-plugins` for each, then start a new session.

`~/.claude/settings.json` registers `ai-workflow-doctor --hook` as a `SessionStart` hook, so a new Claude session starts with
that list (shown to you and given to the model) and with nothing at all when nothing is pending. Details:

- Only the quiet modes look at the remote: one `git fetch` of the chezmoi source, at most every 6 hours (stamp
  `~/.local/state/ai-workflow/source-fetch`), at most 4 seconds, failures ignored. The full report never fetches.
- A session cannot learn that plugins changed after it started: the hook runs at the start, when the installed plugins are
  already what the session loads. After updating plugins, start a new session.
- It covers Claude Code only. Codex has no session hook here; run `ai-workflow-doctor` after an upgrade.
- It never changes anything: it prints the commands, you run them.

