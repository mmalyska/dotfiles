# Global workspace instructions

You are running in a Coder workspace, a Kubernetes pod. These instructions apply in any directory.

- **Put all work in `/workspaces`**: git repositories, projects, experiments and any other files related to the task. Clone new repositories there, not in `/home/vscode`.
- Read `/workspaces/AGENTS.md` first. It describes the environment, persistence, secrets and the repositories already cloned.
- Start sessions inside the relevant directory under `/workspaces` so that repository's own `AGENTS.md` / `CLAUDE.md` is loaded too.
- Don't create project files in `/home/vscode`. The home volume is small (~5 GB) and holds `~/.claude`, `~/.codex`, caches and dotfiles (managed by chezmoi from `mmalyska/dotfiles`).
