#!/usr/bin/env bash
set -euo pipefail

# Master stabilization script to fix UI after monitor plugs or wake events.
# Quickshell owns the bar and follows the bridge's primary-output state; this
# helper changes only the monitor layout and wallpaper.
echo "Stabilizing WM..."
/home/alikebrahim/.config/scripts/x11-monitor-setup.sh
feh --bg-center /home/alikebrahim/Pictures/background.png /home/alikebrahim/Pictures/background.png
echo "Done."
