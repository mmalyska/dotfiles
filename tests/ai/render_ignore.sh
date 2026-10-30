#!/usr/bin/env bash
# Usage: render_ignore.sh <linux|darwin|windows> <true|false>
# Renders a copy of home/.chezmoiignore with .chezmoi.os replaced by the given OS (chezmoi cannot override
# .chezmoi.os from a fixture) and is_devcontainer set to the second argument. Prints the resulting ignore patterns.
# Test-only: the real file is never modified, and the copy is checked to differ from it only by that substitution.
set -euo pipefail
os=${1:?os}
devc=${2:?is_devcontainer}
case "$os" in linux|darwin|windows) ;; *) echo "render_ignore: unknown os '$os'" >&2; exit 2;; esac
case "$devc" in true|false) ;; *) echo "render_ignore: is_devcontainer must be true|false" >&2; exit 2;; esac
root=$(cd "$(dirname "$0")/../.." && pwd)
src="$root/home/.chezmoiignore"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

sed "s/\.chezmoi\.os/\"$os\"/g" "$src" > "$tmp/ignore.tmpl"

# The copy differs from the original only by the substitution: every .chezmoi.os occurrence is gone and
if grep -q '\.chezmoi\.os' "$tmp/ignore.tmpl"; then echo "render_ignore: .chezmoi.os left in the copy" >&2; exit 1; fi
# Compare against the original with only the OS comparisons normalised on both sides.
norm() { sed -E 's/"(linux|darwin|windows)"/OS/g; s/\.chezmoi\.os/OS/g' "$1"; }
if ! diff <(norm "$src") <(norm "$tmp/ignore.tmpl") >/dev/null; then
    echo "render_ignore: the copy differs from home/.chezmoiignore by more than the .chezmoi.os substitution" >&2
    exit 1
fi

printf '[data]\n    is_devcontainer = %s\n' "$devc" > "$tmp/config.toml"
chezmoi --config "$tmp/config.toml" execute-template < "$tmp/ignore.tmpl" | sed '/^[[:space:]]*$/d'
