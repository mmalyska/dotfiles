# `ai-workflow-doctor`

Read-only report on the AI workflow installers, installed by chezmoi to `~/.local/bin/ai-workflow-doctor`.
**`~/.local/bin` must be on `PATH`.**

```sh
ai-workflow-doctor            # report, always exit 0
ai-workflow-doctor --strict   # exit 1 on DRIFT, MISSING or an installer result of "partial"
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
