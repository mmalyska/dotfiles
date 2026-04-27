#!/bin/bash
# Power profiles — fan curves, TDP, and undervolting
# Values decoded 1:1 from G-Helper config (fan_profile_*, limit_*, cpu_uv_*)
#
# Profile mapping (G-Helper JSON suffix → asusctl):
#   _2 (25W)  → Silent
#   _0 (40W)  → Balanced
#   _1 (80W)  → Performance
set -euo pipefail

log()  { echo "==> $*"; }

# ── install ryzenadj if missing ───────────────────────────────────────────────

pacman -Qi ryzenadj &>/dev/null || sudo pacman -S --needed --noconfirm ryzenadj

# ── fan curves ────────────────────────────────────────────────────────────────
# Decoded from G-Helper hex format: first 8 bytes = temps, last 8 = speeds

log "Applying fan curves"

asusctl fan-curve -m Silent      -f cpu -D "62c:0%,65c:6%,69c:15%,73c:23%,77c:30%,80c:38%,85c:51%,90c:100%"
asusctl fan-curve -m Silent      -f gpu -D "62c:0%,66c:7%,70c:13%,74c:22%,79c:31%,84c:41%,88c:68%,90c:99%"

asusctl fan-curve -m Balanced    -f cpu -D "61c:0%,62c:0%,73c:12%,77c:20%,80c:30%,82c:41%,84c:56%,90c:100%"
asusctl fan-curve -m Balanced    -f gpu -D "61c:0%,68c:7%,72c:13%,76c:21%,79c:30%,82c:47%,86c:69%,90c:99%"

asusctl fan-curve -m Performance -f cpu -D "61c:0%,64c:15%,67c:32%,70c:44%,74c:55%,80c:67%,84c:81%,95c:100%"
asusctl fan-curve -m Performance -f gpu -D "62c:0%,65c:19%,68c:30%,72c:45%,76c:57%,80c:71%,84c:85%,95c:100%"

# Enable custom curves for all profiles (overrides BIOS defaults)
for profile in Silent Balanced Performance; do
    asusctl fan-curve -m "$profile" -f cpu -e true
    asusctl fan-curve -m "$profile" -f gpu -e true
done

# ── TDP apply script (called by systemd on boot + resume) ─────────────────────
# Maps current asusctl profile to exact G-Helper TDP values via ryzenadj.
# ryzenadj uses milliwatts; values from limit_* fields in G-Helper JSON.
# All profiles use cpu_temp=98°C (cpu_temp_* fields in JSON).

sudo tee /usr/local/bin/asus-tdp-apply << 'SCRIPT'
#!/bin/bash
# Re-apply ryzenadj TDP for current asusctl profile.
# Survives suspend/resume via asus-tdp.service.
set -euo pipefail

PROFILE=$(asusctl profile -p 2>/dev/null | grep -oP '(?<=Active profile is )\S+' || echo "Balanced")

case "$PROFILE" in
    Silent)
        # limit_slow_2=25, limit_fast_2=25, limit_total_2=25, cpu_temp_2=98
        ryzenadj --stapm-limit=25000 --slow-limit=25000 --fast-limit=25000 --tctl-temp=98
        ;;
    Balanced)
        # limit_total_0=40, limit_slow_0=60, limit_fast_0=60, cpu_temp_0=98
        ryzenadj --stapm-limit=40000 --slow-limit=60000 --fast-limit=60000 --tctl-temp=98
        ;;
    Performance)
        # limit_total_1=80, limit_slow_1=80, limit_fast_1=80, cpu_temp_1=98
        ryzenadj --stapm-limit=80000 --slow-limit=80000 --fast-limit=80000 --tctl-temp=98
        ;;
    *)
        # Fallback to Balanced values
        ryzenadj --stapm-limit=40000 --slow-limit=60000 --fast-limit=60000 --tctl-temp=98
        ;;
esac
SCRIPT
sudo chmod +x /usr/local/bin/asus-tdp-apply

# ── systemd service — apply TDP on boot and resume from sleep ─────────────────

sudo tee /etc/systemd/system/asus-tdp.service << 'UNIT'
[Unit]
Description=ASUS G14 — re-apply ryzenadj TDP limits
# Runs on boot and after resume (ryzenadj settings reset on suspend)
After=suspend.target hibernate.target hybrid-sleep.target
After=asusd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/asus-tdp-apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now asus-tdp.service

# ── CPU undervolting: -10 mV (cpu_uv_* = -10 across all profiles) ────────────
# asusctl exposes the ASUS WMI undervolting interface used by G-Helper.
# Requires asusctl 6.x+ with Strix Point UV support.

log "Applying CPU undervolt: -10 mV"
if asusctl --help 2>&1 | grep -q "cpu-uv\|undervolt"; then
    asusctl --cpu-uv -10
else
    echo "!!! asusctl --cpu-uv not available on this version."
    echo "    Check: https://asus-linux.org — update asusctl or apply via BIOS"
fi

log "Done — 003-power-profiles"
log ""
log "  Switch profiles with:  asusctl profile -P Silent|Balanced|Performance"
log "  Or Fn+F5 cycles through them"
log "  TDP re-applies automatically on resume via asus-tdp.service"
