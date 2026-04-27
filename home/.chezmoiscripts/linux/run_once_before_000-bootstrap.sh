#!/bin/bash
# Bootstrap paru (AUR helper) on Arch/CachyOS if not already present.
# CachyOS ships paru by default; this is a safety net for vanilla Arch.
set -euo pipefail

if command -v paru &>/dev/null; then
    echo "paru already installed, skipping"
    exit 0
fi

echo "==> Bootstrapping paru"
sudo pacman -S --needed --noconfirm base-devel git
git clone https://aur.archlinux.org/paru.git /tmp/paru-bootstrap
(cd /tmp/paru-bootstrap && makepkg -si --noconfirm)
rm -rf /tmp/paru-bootstrap
echo "==> paru installed"
