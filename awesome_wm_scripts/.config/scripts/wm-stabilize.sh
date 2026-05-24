#!/usr/bin/env bash
set -euo pipefail

# Master stabilization script to fix UI after monitor plugs or wake events
echo "Stabilizing WM..."
/home/alikebrahim/.config/scripts/x11-monitor-setup.sh
/home/alikebrahim/.config/polybar/launch.sh
feh --bg-fill /home/alikebrahim/Pictures/background.png /home/alikebrahim/Pictures/background.png
echo "Done."
