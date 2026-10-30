# T08 – Codex CLI evidence (steps 1–2)

Date: 2026-10-30. `codex-cli 0.164.0`, `chezmoi` v2.73.1, Homebrew on Linux. Every Codex run used an isolated
`CODEX_HOME` under `~/.cache/ai-workflow-test.*` (outside `/tmp`, removed afterwards). The real `~/.codex` was not touched.
Nothing was pushed or changed on GitHub.

## Step 2 – CLI contract (real GitHub, `mmalyska/claude-plugins` at `25d785abee26ca7a3c87e8311f46e8a90f225301`)

| Command | Result |
| --- | --- |
| `plugin marketplace list --json` (empty) | `{"marketplaces": []}`, exit 0 |
| `plugin marketplace add mmalyska/claude-plugins --ref <sha>` (1st) | "Added marketplace `mmalyska-claude-plugins` … #<sha>", exit 0 |
| same command (2nd) | "already added from … #<sha>", **exit 0** (idempotent) |
| `plugin marketplace list --json` | `{"marketplaces": [{name, root, marketplaceSource: {sourceType, source}}]}` (the ref is **not** in the JSON) |
| `plugin list --json` (empty) | `{"installed": [], "available": []}`, exit 0 |
| `plugin add git-workflows@mmalyska-claude-plugins` (1st and 2nd) | installed, **exit 0 both times** (idempotent) |
| `plugin list --json` | `installed[]` of `{pluginId: "<plugin>@<marketplace>", name, marketplaceName, version, installed, enabled, …}` |
| `plugin marketplace add mmalyska/claude-plugins --ref main` (marketplace already pinned to the SHA) | **exit 1**: "already added from a different source; remove it before adding this source"; config unchanged |

`config.toml` after the runs:

```toml
[marketplaces.mmalyska-claude-plugins]
source_type = "git"
source = "https://github.com/mmalyska/claude-plugins.git"
ref = "25d785abee26ca7a3c87e8311f46e8a90f225301"

[plugins."git-workflows@mmalyska-claude-plugins"]
enabled = true
```

### Consequences for the installer

- The pinned ref lives only in `config.toml`, so the installer (and the doctor) read `ref` from `[marketplaces.<name>]` there.
- Idempotence exists, but the installer still checks `marketplace list --json` and `plugin list --json` first and calls only what is
  missing, so a rerun with full state makes zero mutating calls (same shape as the Claude installer).
- A different ref cannot be re-added over an existing marketplace (exit 1). The installer therefore never calls `marketplace add` for
  an existing marketplace; it reads the ref and prints `WARN pin mismatch` (no automatic replacement, no `marketplace remove`/`upgrade`).

## Step 1 – CLI package identifiers

| Platform | Tool | Codex | Claude Code | Verdict |
| --- | --- | --- | --- | --- |
| macOS / Linuxbrew | `brew info` | cask `codex` ("Codex", 0.166.0, https://github.com/openai/codex) | cask `claude-code` (already installed by the macOS script) | **verified** |
| any | `npm view` | `@openai/codex` (bin `codex`) | `@anthropic-ai/claude-code` | verified, but npm is not the install path used by this repo |
| Arch | `pacman -Si` / `paru -Si` | not available on this host | not available | NOT VERIFIED |
| Windows | `winget show` | not available on this host | not available | NOT VERIFIED |

Only the verified brew cask `codex` was added (macOS, guarded by `ai_codex`). Linux (pacman/AUR) and Windows (winget) get **no**
Codex package: no evidence, so CLI installation stays out of scope there (R6).

## Native run of the installer (`AI_NATIVE_TESTS=1 tests/ai/e2e-codex.sh`)

Real `codex` 0.164.0 and GitHub, isolated `CODEX_HOME`, profile `core`: first run added the marketplace with `--ref 25d785a…` and 12
plugins (`DONE codex fails=0`, `result=ok`); the second run made no mutating call and `config.toml` was byte-identical
(`ref = "25d785a…"`, `[plugins."git-workflows@mmalyska-claude-plugins"] enabled = true`). Without a `codex` CLI or network the test
exits 77 and the runner prints `NOT RUN` with the reason.
