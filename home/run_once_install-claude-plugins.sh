#!/bin/bash
set -euo pipefail

claude plugin marketplace add mmalyska/claude-plugins || true
claude plugin marketplace update mmalyska-claude-plugins
claude plugin install personal-essentials@mmalyska-claude-plugins
claude plugin install git-workflows@mmalyska-claude-plugins
claude plugin install development-lifecycle@mmalyska-claude-plugins
claude plugin install dotnet@mmalyska-claude-plugins
claude plugin install frontend@mmalyska-claude-plugins
claude plugin install backend@mmalyska-claude-plugins
claude plugin install devops@mmalyska-claude-plugins
claude plugin install security@mmalyska-claude-plugins
claude plugin install agent-toolkit@mmalyska-claude-plugins
claude plugin install renovate@mmalyska-claude-plugins
claude plugin install devcontainer@mmalyska-claude-plugins
claude plugin install android@mmalyska-claude-plugins

claude plugin install superpowers@claude-plugins-official || true
claude plugin install code-simplifier@claude-plugins-official || true
claude plugin install context7@claude-plugins-official || true
claude plugin install claude-md-management@claude-plugins-official || true
