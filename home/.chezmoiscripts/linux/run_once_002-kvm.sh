#!/bin/bash
# KVM/QEMU — Windows VM with NVIDIA GPU passthrough.
# Topology: AMD Radeon 890M (iGPU) → Linux | RTX 50xx (dGPU) → Windows VM
# Use case: Ableton Live 12, Luminar Neo
# Prerequisite: enable AMD-Vi / SVM Mode in BIOS before running.
set -euo pipefail

log()  { echo "==> $*"; }
skip() { echo "··· $* (already done)"; }
warn() { echo "!!! $*"; }

# ── IOMMU check ───────────────────────────────────────────────────────────────

dmesg | grep -qi "iommu" \
    || warn "IOMMU not active — enable AMD-Vi (SVM Mode) in BIOS for GPU passthrough"

# ── IOMMU + VFIO kernel parameters ───────────────────────────────────────────

CMDLINE="/etc/kernel/cmdline"
if [[ -f "$CMDLINE" ]]; then
    CURRENT=$(cat "$CMDLINE")
    UPDATED="$CURRENT"
    for param in "amd_iommu=on" "iommu=pt"; do
        echo "$CURRENT" | grep -q "$param" || UPDATED="$UPDATED $param"
    done
    [[ "$UPDATED" == "$CURRENT" ]] \
        && skip "IOMMU kernel parameters" \
        || { log "Adding IOMMU kernel parameters"; echo "$UPDATED" | sudo tee "$CMDLINE"; }
fi

# ── VFIO modules ─────────────────────────────────────────────────────────────

VFIO_CONF="/etc/modules-load.d/vfio.conf"
[[ -f "$VFIO_CONF" ]] && skip "VFIO modules" || {
    log "Configuring VFIO modules"
    printf 'vfio\nvfio_iommu_type1\nvfio_pci\n' | sudo tee "$VFIO_CONF"
}

# ── KVM / QEMU / virt-manager ────────────────────────────────────────────────

pacman -Qi qemu-full &>/dev/null && skip "qemu + libvirt" || {
    log "Installing KVM/QEMU stack"
    sudo pacman -S --needed --noconfirm \
        qemu-full libvirt virt-manager virt-viewer \
        dnsmasq bridge-utils edk2-ovmf swtpm looking-glass
}

for svc in libvirtd virtlogd; do
    systemctl is-enabled "$svc" &>/dev/null \
        || { log "Enabling $svc"; sudo systemctl enable --now "$svc"; }
done

sudo virsh net-list --all | grep -q "default.*active" || {
    sudo virsh net-autostart default
    sudo virsh net-start default 2>/dev/null || true
}

# ── user groups ───────────────────────────────────────────────────────────────

for group in libvirt kvm input; do
    groups "$USER" | grep -q "$group" \
        || { log "Adding $USER to $group"; sudo usermod -aG "$group" "$USER"; }
done

# ── looking-glass shared memory ───────────────────────────────────────────────

LGCONF="/etc/tmpfiles.d/10-looking-glass.conf"
[[ -f "$LGCONF" ]] && skip "looking-glass shm" || {
    log "Configuring looking-glass shared memory"
    printf "f\t/dev/shm/looking-glass\t0660\t%s\tkvm\t-\n" "$USER" | sudo tee "$LGCONF"
    sudo systemd-tmpfiles --create "$LGCONF"
}

# ── hugepages ─────────────────────────────────────────────────────────────────

HP_CONF="/etc/sysctl.d/10-hugepages.conf"
[[ -f "$HP_CONF" ]] && skip "hugepages" || {
    log "Configuring hugepages (2GB default — raise for Ableton sessions)"
    echo "vm.nr_hugepages = 1024" | sudo tee "$HP_CONF"
}

# ── vfio-bind helper ─────────────────────────────────────────────────────────

mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/vfio-bind" << 'SCRIPT'
#!/usr/bin/env bash
# vfio-bind on   — bind NVIDIA dGPU to vfio-pci (start Windows VM session)
# vfio-bind off  — rebind NVIDIA dGPU to nvidia-open (return to Linux)
set -euo pipefail
ACTION="${1:-}"
NVIDIA_IDS=$(lspci -nn | grep -i nvidia | grep -oP '(?<=\[)[\da-f]{4}:[\da-f]{4}(?=\])' | paste -sd,)
[[ -z "$NVIDIA_IDS" ]] && { echo "No NVIDIA device found"; exit 1; }
case "$ACTION" in
    on)
        sudo modprobe vfio vfio_iommu_type1 vfio_pci
        echo "options vfio-pci ids=$NVIDIA_IDS" | sudo tee /etc/modprobe.d/vfio-pci.conf
        supergfxctl -m Dedicated
        echo "Ready — start VM in virt-manager, then: looking-glass-client"
        ;;
    off)
        sudo rm -f /etc/modprobe.d/vfio-pci.conf
        supergfxctl -m Hybrid
        echo "Done — reboot or reload nvidia modules to restore Linux GPU"
        ;;
    *)  echo "Usage: vfio-bind [on|off]"; exit 1 ;;
esac
SCRIPT
chmod +x "$HOME/.local/bin/vfio-bind"

log "Done — 002-kvm"
log "  Workflow: vfio-bind on → virt-manager → looking-glass-client → vfio-bind off"
