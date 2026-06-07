#!/bin/bash
set -euo pipefail

echo "==> Installing peon-ping"
bash <(curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh) --packs peon
