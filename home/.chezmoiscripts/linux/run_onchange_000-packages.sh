#!/bin/bash
# Arch/CachyOS package installs via pacman + paru.
# Mirrors: .chezmoiscripts/windows/run_onchange_000-packages.ps1.tmpl
# Reruns whenever this file changes (run_onchange_).
set -euo pipefail

_pac() {
    for pkg in "$@"; do
        pacman -Qi "$pkg" &>/dev/null && echo "··· $pkg (already installed)" && continue
        echo "==> Installing $pkg"
        sudo pacman -S --needed --noconfirm "$pkg"
    done
}

_aur() {
    for pkg in "$@"; do
        paru -Qi "$pkg" &>/dev/null && echo "··· $pkg (already installed)" && continue
        echo "==> Installing AUR: $pkg"
        paru -S --needed --noconfirm "$pkg"
    done
}

sudo pacman -Syu --noconfirm

# ── common (mirrors Windows: gh, vscode, claude, peon-ping) ───────────────────
_pac git github-cli code
_aur claude-desktop-bin

# ── core CLI ──────────────────────────────────────────────────────────────────
_pac curl wget unzip ripgrep fd bat btop lazygit zsh fzf jq yq tmux

# ── dev tooling ───────────────────────────────────────────────────────────────
_pac nodejs npm python python-pip dotnet-sdk docker docker-compose
_aur jetbrains-toolbox

# ── productivity & communication ──────────────────────────────────────────────
_aur zen-browser-bin anytype-bin insomnia-bin
_pac signal-desktop discord bitwarden wireguard-tools

# ── creative ──────────────────────────────────────────────────────────────────
_pac strawberry musicbrainz-picard darktable

# ── gaming ────────────────────────────────────────────────────────────────────
_pac steam lutris wine winetricks gamemode mangohud prism-launcher
_aur heroic-games-launcher-bin

# ── hardware monitoring (replaces HWiNFO / SeaTools on Windows) ───────────────
_pac nvtop lm_sensors smartmontools powertop s-tui
_aur amdgpu_top

# ── audio — full Wayland / pipewire stack ─────────────────────────────────────
_pac pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber easyeffects

# ── system utilities ──────────────────────────────────────────────────────────
_pac timeshift flatpak filezilla wl-clipboard brightnessctl

# ── SRE / infra ───────────────────────────────────────────────────────────────
_pac kubectl helm terraform k9s stern
_aur lm-studio-bin

# ── ASUS ROG + NVIDIA (RTX 50 Blackwell — nvidia-open ONLY, never nvidia) ────
_pac asusctl supergfxctl rog-control-center power-profiles-daemon
_pac nvidia-open nvidia-utils nvidia-settings lib32-nvidia-utils egl-wayland

for svc in asusd supergfxd power-profiles-daemon; do
    systemctl is-enabled "$svc" &>/dev/null \
        || sudo systemctl enable --now "$svc"
done

# Battery charge limit — OLED longevity (80% for daily plugged-in use)
asusctl -c 80

# Default GPU mode: Hybrid (AMD iGPU for desktop, NVIDIA on-demand via PRIME)
supergfxctl -g | grep -q "Hybrid" || supergfxctl -m Hybrid

# Docker group
groups "$USER" | grep -q docker || sudo usermod -aG docker "$USER"
