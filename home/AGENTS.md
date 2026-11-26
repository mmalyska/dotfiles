# Global workspace instructions (shared by Claude Code and Codex)

You are running in a Coder workspace, a Kubernetes pod. These instructions apply in any directory.

- **Put all work in `/workspaces`**: git repositories, projects, experiments and any other files related to the task. Clone new repositories there, not in `/home/vscode`.
- Read `/workspaces/AGENTS.md` first. It describes the environment, persistence, secrets and the repositories already cloned.
- Start sessions inside the relevant repository under `/workspaces`, so that its own `AGENTS.md` / `CLAUDE.md` is loaded too.
- **A session that started elsewhere does not load a repository's instructions** (for example a session started in `/workspaces`). Before the first command that touches a repository, reads and greps included, read its `AGENTS.md` (or `CLAUDE.md`, else `README.md`) in full and follow it. Do this once per repository per session.
- Don't create project files in `/home/vscode`. The home volume is small (~5 GB) and holds `~/.claude`, `~/.codex`, caches and dotfiles (managed by chezmoi from `mmalyska/dotfiles`).
