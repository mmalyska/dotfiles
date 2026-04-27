#!/bin/bash
# ASUS ROG Zephyrus G14 2025 — one-time hardware configuration.
# RTX 50 / Blackwell: nvidia-open required, proprietary driver unsupported.
set -euo pipefail

log()  { echo "==> $*"; }
skip() { echo "··· $* (already done)"; }

# ── NVIDIA open modules in initramfs ─────────────────────────────────────────

MKINIT="/etc/mkinitcpio.conf"
if ! grep -q "nvidia_drm" "$MKINIT" 2>/dev/null; then
    log "Adding NVIDIA modules to mkinitcpio"
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINIT"
    sudo mkinitcpio -P
else
    skip "mkinitcpio NVIDIA modules"
fi

# ── nvidia DRM modeset — required for Wayland ─────────────────────────────────

CMDLINE="/etc/kernel/cmdline"
if [[ -f "$CMDLINE" ]] && ! grep -q "nvidia_drm.modeset" "$CMDLINE"; then
    log "Enabling nvidia_drm.modeset"
    echo "$(cat "$CMDLINE") nvidia_drm.modeset=1" | sudo tee "$CMDLINE"
else
    skip "nvidia_drm.modeset"
fi

# ── sensors ───────────────────────────────────────────────────────────────────

ls /sys/class/hwmon/hwmon*/name 2>/dev/null | xargs cat 2>/dev/null | grep -q k10temp \
    || sudo sensors-detect --auto

log "Done — reboot to apply initramfs + cmdline changes"
