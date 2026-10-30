# T06 – Claude Code CLI evidence (steps 1–2, spike S1)

Date: 2026-10-30. `claude` 2.1.314, `chezmoi` v2.73.1. Every run used an isolated `CLAUDE_CONFIG_DIR` under `~/.cache/ai-spike.*`
(outside `/tmp`, removed afterwards). The real `~/.claude` was not touched. Nothing was pushed or changed on GitHub.

## Step 1 – CLI contract (real GitHub, `mmalyska/claude-plugins`)

| Command | Result |
| --- | --- |
| `plugin marketplace list --json` (empty) | `[]`, exit 0 |
| `plugin marketplace add mmalyska/claude-plugins` (1st) | clones, exit 0 |
| `plugin marketplace add mmalyska/claude-plugins` (2nd) | "already on disk", **exit 0** (idempotent) |
| `plugin marketplace list --json` | array of `{name, source, repo, installLocation}` (`url`/`ref` instead of `repo` for git sources) |
| `plugin list --json` (empty) | `[]`, exit 0 |
| `plugin install git-workflows@mmalyska-claude-plugins` (1st) | installed, exit 0 |
| `plugin install git-workflows@mmalyska-claude-plugins` (2nd) | "already installed (scope: user)", **exit 0** (idempotent) |
| `plugin list --json` | array of `{id: "<plugin>@<marketplace>", version, scope, enabled, installPath, …}` |

`--json` exists on `list`, `marketplace list`, `marketplace add` and `install`. The installer therefore reads installed
state from `plugin list --json` (field `id`) and `marketplace list --json` (field `name`) and installs only what is missing,
instead of relying on idempotence.
The marketplace checkout was at `25d785abee26ca7a3c87e8311f46e8a90f225301` (the accepted SHA was still the branch head).

## Step 2 – Spike S1: pin by tag (local tag, local git remote)

Setup: clone of `claude-plugins` at `25d785a`, **local** tag `ai-workflow-v0.1.0-preview.1`, plus a later commit on the
served branch (`ca8db09`, remote `HEAD`), so that "tag" and "branch head" differ. Served over smart HTTP from
`127.0.0.1` (`git http-backend`), because the CLI rejects `file://`, `git+file://` and `path#ref` ("Invalid marketplace source format"
/ "Path does not exist").

| Probe | Result |
| --- | --- |
| (a) `marketplace add "http://…/cp2.git#ai-workflow-v0.1.0-preview.1"` | exit 0; `git rev-parse HEAD` in the marketplace dir == `25d785a…` (tag, **not** the branch head `ca8db09`); `marketplace list --json` stores `source: git`, `ref: <tag>` |
| control: same URL without `#ref` | HEAD == `ca8db09` (branch head), so the ref is what pins |
| (b) `settings.json` `extraKnownMarketplaces.<m>.source = {source: git, url, ref: <tag>}` | the CLI does not materialise settings-declared marketplaces by itself (`install` → "not found in marketplace"); `marketplace add "<url>#<tag>"` is accepted and HEAD == `25d785a…`; `marketplace add "<url>"` without the ref is **rejected** ("its source doesn't match its extraKnownMarketplaces entry"), i.e. the settings `ref` is enforced |
| (c) `marketplace update` after (a) and after (b) | exit 0; HEAD stays `25d785a…` (does not move to the branch head) |
| (d) SHA as ref: `mmalyska/claude-plugins#<40-hex>` | rejected (clone failure) – as measured earlier in plan §1.3 |

### Decision

Tag pinning works for Claude Code in (a)+(b)+(c) with a **git-URL** source. Consequence for T14: it **may** switch `pin_mode` to `tag`
after the real tag exists. Not verified here (to be repeated in T14 on the real tag, nothing is assumed):
the GitHub shorthand `owner/repo#tag`, and a `{"source":"github","repo":…,"ref":…}` entry (only the `git`+`url` form was
tested, because the CLI cannot fetch a local tag from GitHub). Until then `pin_mode: verify` stays and the installer verifies
`HEAD == accepted_sha` (WARN on drift). The installer does not use `ref`.
