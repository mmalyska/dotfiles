#!/bin/bash
# Install Homebrew — macOS package manager.
# Runs once; subsequent runs are no-ops (Homebrew self-detects).
set -euo pipefail
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
