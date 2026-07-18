#!/usr/bin/env bash
set -euo pipefail

# Master stabilization script to fix UI after monitor plugs or wake events.
# Polybar has been replaced by the native AwesomeWM pill bar — do not relaunch it.
# The bar will reposition itself via screen::primary_changed / list signals.
echo "Stabilizing WM..."
/home/alikebrahim/.config/scripts/x11-monitor-setup.sh
feh --bg-center /home/alikebrahim/Pictures/background.png /home/alikebrahim/Pictures/background.png
echo "Done."
