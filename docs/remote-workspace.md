# Remote workspace (Coder on Kubernetes)

A remote workspace is a long-lived pod that runs the `dev-workstation` image, started from a Coder template. The pod has no TTY
during bootstrap, so `chezmoi init` must not prompt, and a few settings differ from a laptop or a local devcontainer. Everything
here applies only when the workspace flag is set; every other host renders exactly what it rendered before.

## The flag

`home/.chezmoi.toml.tmpl` sets `is_remote_workspace = true` at `chezmoi init` when `CODER=true` (the Coder agent sets it) or
`REMOTE_WORKSPACE` is non-empty (manual override). It is computed on every init and never prompted.

## Non-interactive init

```sh
chezmoi init --apply --promptDefaults mmalyska/dotfiles
```

`--promptDefaults` answers every prompt with its default, so nothing waits for input: a new host gets the `core` AI profile with
Claude and Codex plugins and the default git identity. To answer differently without a TTY, pass the answers as flags, keyed by the
prompt text, for example `--promptString "Email address for git=you@example.org"` and `--promptChoice "AI profile=minimal"`.
`tests/ai/lib.sh` lists the prompt texts. A host that already has a chezmoi config is not asked again.

## What the flag changes

| Where | With the flag unset | With the flag set |
| ----- | ------------------- | ----------------- |
| `home/dot_gitconfig.tmpl`, `user.signingkey` | the owner's own public key | `remote_workspace.signing_key` from `home/.chezmoidata/remote-workspace.yaml`, when it is not empty; otherwise unchanged |
| `home/dot_gitconfig.tmpl`, `[credential "https://github.com"]` | not set | `gh auth git-credential` is the helper, so `git push` over HTTPS uses `GITHUB_TOKEN` from the environment (the template exports it from BWS). Nothing is written to disk; the empty `helper =` line first drops any inherited helper |
| `home/.chezmoiscripts/workspace/run_onchange_after_200-clone-repos.sh.tmpl` | renders to nothing, so chezmoi skips it | clones every repository in `remote_workspace.repositories` that is missing, to `/workspaces/<name>` |
| `home/AGENTS.md` (`~/AGENTS.md`) | not managed | the one real copy of the global agent instructions for any directory: all work goes in `/workspaces`, read `/workspaces/AGENTS.md` first |
| `home/dot_codex/symlink_AGENTS.md.tmpl` (`~/.codex/AGENTS.md`) | not managed | a symlink to `~/AGENTS.md`: Codex reads its global file in every session and does not support `@` imports, but follows symlinks |
| `home/dot_claude/CLAUDE.md.tmpl` (`~/.claude/CLAUDE.md`) | not managed | one line importing `~/AGENTS.md`, so Claude Code gets the same text in any directory (its always-loaded user file is `CLAUDE.md`) |

**Signing key.** The workspace has its own dedicated SSH signing key (public half already in the data file). Its private half is in the workspace's Bitwarden project and
is loaded into an in-pod `ssh-agent` by the Coder template; this repository holds only the public half. Put the public key (one
line, `ssh-ed25519 AAAA…`) in `remote_workspace.signing_key`. If it is emptied the owner's own key stays, which cannot sign inside
the workspace, so commits fail loudly instead of being signed by the wrong key.

**Repositories.** The list is public data (`owner/name`). The script uses `gh repo clone` (it authenticates with `GITHUB_TOKEN` for
private repositories) and falls back to `git clone` over HTTPS. A directory that already exists is never touched, and a failed
clone is reported on stderr without stopping the apply. The script re-runs when the list changes.

## No `.devcontainer` flow

A remote workspace serves several repositories and does not run a repository's `.devcontainer` lifecycle scripts. The clone
script therefore lives in `home/.chezmoiscripts/workspace/`, not in `devcontainer/`, so it does not depend on `is_devcontainer`
(which is true for any user named `vscode`). Per-repository setup is done by hand for now.

## Tests

`tests/ai/test_remote_workspace.sh` (part of `tests/ai/run.sh`, no network, `git` and `gh` are stubs) checks that the gitconfig is
byte-identical to `tests/ai/golden/gitconfig.*` with the flag unset, that the key and the clones appear with it set, that the script
skips, clones and reports failures correctly, that no ignore pattern hides it, that peon-ping is skipped only in a workspace, and that `chezmoi init --promptDefaults` without a TTY follows the environment.

## peon-ping is skipped in a workspace

The `devcontainer/run_once_000-peon-ping.sh` sound-pack install needs an audio relay on the owner's host, which a pod cannot reach, so
`home/.chezmoiignore` ignores it when `is_remote_workspace` is set (in addition to the devcontainer rule). Other devcontainers keep
it. It also registers Claude Code hooks in `settings.json`; skipping the script removes that overhead from every tool call.
A home volume that already ran it keeps the installed hooks: remove them with `bash ~/.claude/hooks/peon-ping/uninstall.sh`.
