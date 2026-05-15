#!/bin/bash
set -euo pipefail

claude plugin marketplace add mmalyska/claude-plugins
claude plugin install personal-essentials@mmalyska-claude-plugins
claude plugin install git-workflows@mmalyska-claude-plugins
claude plugin install development-lifecycle@mmalyska-claude-plugins
claude plugin install dotnet@mmalyska-claude-plugins
claude plugin install frontend@mmalyska-claude-plugins
claude plugin install renovate@mmalyska-claude-plugins
claude plugin install devcontainer@mmalyska-claude-plugins
claude plugin install android@mmalyska-claude-plugins
