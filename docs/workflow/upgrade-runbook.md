# Runbook: upgrade, rollback, migration and backup

Applies to the AI workflow installers (`100-claude-plugins`, `110-codex-plugins`) and `~/.claude/settings.json`.
Design background: [plan.md](../plans/hybrid-ai-workflow-dotfiles/plan.md) (D-C1 recovery, D-D pin, D-G host detection).
Accepted revision and pin policy: [acceptance.md](acceptance.md). Report tool: [doctor.md](doctor.md).

Principles: nothing is ever uninstalled by dotfiles; a profile change only disables; retry after a failure is manual and
touches exactly one script; the CLIs may rewrite files that chezmoi manages (see step 4).
`~/.local/bin` must be on `PATH` for `ai-workflow-doctor`. Commands assume the chezmoi source is the default
`~/.local/share/chezmoi` (otherwise add `--source <dir>`).

## 0. Choosing a profile (`chezmoi init`)

Profiles: `minimal` (2 plugins), `core` (12, default for new hosts), `claude-extended` (12 + 4 Claude extras, what existing hosts keep).

| Situation | Command |
| --- | --- |
| Container or CI without a TTY | `chezmoi init --promptDefaults` (`--no-tty` fails; without any flag and without a TTY `init` fails) |
| New host, explicit profile | `chezmoi init --promptDefaults --promptChoice "AI profile=minimal"` |
| Conscious change on an existing host | `chezmoi init --prompt --promptChoice "AI profile=core" --promptBool "Enable Claude agent teams=false"` |
| Switch a harness off | `--promptBool "Configure Claude Code plugins=false"` or `--promptBool "Configure Codex plugins=false"` |

The flags are keyed by the **prompt text**, not by the data key. Without `--prompt`, an answer already stored in the
configuration file wins over the flag. An existing host without `ai_profile` gets `claude-extended` and agent teams
written explicitly and without a question. Equivalent manual route: edit `[data]` in `~/.config/chezmoi/chezmoi.toml`.

## 1. Backup (before the first apply of a new version, before any upgrade)

`chezmoi apply` overwrites `~/.claude/settings.json`, including changes made by Claude itself or by `/config`.

```sh
bash ~/.local/share/chezmoi/docs/workflow/backup.sh
```

It copies, and changes nothing else, into `~/.local/state/ai-workflow-backup/<UTC>/` (mode 0700, never overwrites an earlier backup):

| File | Source |
| --- | --- |
| `settings.json` | `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json` |
| `config.toml` | `${CODEX_HOME:-~/.codex}/config.toml` |
| `claude-plugins.json` | `claude plugin list --json` |
| `codex-plugins.txt` | `codex plugin list` |

A missing file or CLI is reported as `SKIP`. Exit 1 only when nothing could be saved. Restoring is manual: copy the file back.

## 2. Try the new revision in an isolated home

Never test an upgrade on the live home first.

```sh
cd ~/.local/share/chezmoi   # a branch with the proposed accepted_sha
bash tests/ai/run.sh                                  # deterministic layer A, stubs, offline
AI_NATIVE_TESTS=1 bash tests/ai/run.sh                # layer B: real CLIs and network, in HOME=~/.cache/ai-e2e.*
```

Layer B uses throw-away homes below `~/.cache` (not `/tmp`: Codex refuses `CODEX_HOME` aliases there), needs a real
`claude` and/or `codex`, and reports `NOT RUN <reason>` for what it cannot run. It never touches `~/.claude` or `~/.codex`.

## 3. Pull request that changes the accepted revision

In one pull request: `accepted_sha` (and `accepted_tag` once a tag exists) in `home/.chezmoidata/ai-workflow.yaml`, and
a new row in [acceptance.md](acceptance.md) (SHA, date, CLI versions, test results). CI must be green.
Both installers embed `accepted_sha` in their fingerprint, so the next `chezmoi apply` runs them again once.

## 4. Apply the upgrade

```sh
chezmoi git pull        # or: git -C ~/.local/share/chezmoi pull
chezmoi diff            # read it; settings.json is the file that matters
AI_WORKFLOW_UPGRADE=1 chezmoi apply
```

`AI_WORKFLOW_UPGRADE=1` is the only thing that makes the Claude installer run `claude plugin marketplace update`.
Without it the installers never update an existing marketplace.

**`settings.json` and the Claude CLI.** `~/.claude/settings.json` stays fully managed by chezmoi. Installing a plugin makes the
`claude` CLI rewrite it (same content, other key order), which would make the next `chezmoi apply` stop at
`settings.json has changed since chezmoi last wrote it`. The Claude installer therefore saves the exact bytes and mode before its
first mutating command and always puts them back afterwards (a file the CLI created is removed). A plain `chezmoi apply` is
expected to work without `--force`. If the installer logs `could not restore … settings.json` the result is `partial`: copy
`settings.json` back from the step 1 backup (or run `chezmoi apply --force` once after reading `chezmoi diff`) and use the recovery below.
Background and measurements: [evidence/T13-e2e.md](evidence/T13-e2e.md), plan D-H.

### Claude Code

```sh
claude plugin marketplace update mmalyska-claude-plugins     # done by the installer when AI_WORKFLOW_UPGRADE=1
claude plugin update <name>@mmalyska-claude-plugins          # for each plugin whose version changed
```

Then start a **new** Claude Code session. The installer warns `drift` when the marketplace checkout is not at `accepted_sha`;
the Claude CLI cannot pin a SHA (`pin_mode: verify`).

### Codex

The marketplace is pinned with `--ref <accepted_sha>`. Measured with codex 0.164.0: `codex plugin marketplace add
mmalyska/claude-plugins --ref <other>` over an existing entry **fails** (exit 1, `already added from a different source;
remove it before adding this source`) and leaves the old ref. The installer therefore only warns `pin mismatch` and never
replaces the entry. To move the pin, by hand:

```sh
codex plugin marketplace remove mmalyska-claude-plugins
codex plugin marketplace add mmalyska/claude-plugins --ref <new accepted_sha>
codex plugin add <name>@mmalyska-claude-plugins              # idempotent; repeat per plugin
```

Measured: remove followed by add with the accepted ref ends with that ref in `config.toml`.

## 5. Verify

```sh
ai-workflow-doctor --strict
```

Exit 0: every installed marketplace is `OK`, all plugins of the profile present, no installer `partial`. `skipped`
(CLI missing or `ai_*=false`) is not an error.

### Recovery after a partial install

An installer that hit an error still exits 0 (so the apply and the other harness go on) and records `result=partial`.
chezmoi counts that script as done, so a plain `chezmoi apply` does **not** retry it. The sequence is manual and resets
exactly one script:

```text
failure -> ai-workflow-doctor --strict -> chezmoi state delete --bucket=entryState --key=<printed key> -> chezmoi apply -> ai-workflow-doctor --strict
```

The doctor prints the exact commands for the failed harness (it never runs them), for example:

```sh
chezmoi state delete --bucket=entryState --key="$HOME/.chezmoiscripts/ai/100-claude-plugins.sh"
chezmoi apply
```

Only that script runs again; the rest of `apply` proceeds normally (preview with `chezmoi apply --dry-run --verbose`).

**Forbidden.** Do not run `chezmoi state delete-bucket` on any bucket and do not run `chezmoi state reset`.
Never use `delete-bucket --bucket=scriptState`: it does not reset `run_onchange_` scripts (their state is in `entryState`) but
runs every `run_once_` script again, including the `sudo`/`pacman` ones under `.chezmoiscripts/linux/`. Never reset the whole
`entryState` bucket either: it forgets every script and file. Reset a single key only.

## 6. Rollback

1. Restore the previous revision: a pull request (or `git revert`) that sets `accepted_sha` back and adds the acceptance row.
2. Repeat steps 4 and 5 with it. Codex needs the `remove` + `add --ref` pair from step 4 (the ref cannot be edited in place).
   Claude: `claude plugin marketplace update` moves the checkout to the source's latest, not to an older SHA. For an older
   state, remove and re-add the marketplace by hand and reinstall the affected plugins, then check `ai-workflow-doctor`.
3. A bad `settings.json`: copy `settings.json` from the backup in step 1 back, or `git revert` the template change and apply.
4. To undo a whole feature pull request: `git revert <merge commit>`, then `chezmoi apply`. Keys such as `ai_profile` that
   `chezmoi init` wrote into `chezmoi.toml` stay behind as unused data; they are harmless.

## 7. Changing the profile and removing plugins

A profile change (step 0) only edits `enabledPlugins` in `settings.json`; for example `claude-extended` to `core` drops the four
`@claude-plugins-official` entries. Nothing is uninstalled and no `uninstall`, `remove` or `disable` call is ever made by
dotfiles. To remove for real, by hand and one at a time:

```sh
claude plugin uninstall <name>@<marketplace>
codex plugin remove <name>@mmalyska-claude-plugins
codex plugin marketplace remove mmalyska-claude-plugins      # only if nothing else uses it
claude plugin marketplace remove <name>
```

Disabling Superpowers (`claude plugin disable superpowers@claude-plugins-official`) never breaks `chezmoi apply` or the doctor.
Run `bash docs/workflow/backup.sh` first.
