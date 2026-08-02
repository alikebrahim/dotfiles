# Retired Rofi and Polybar helpers

Retired: 2026-07-30
Original package paths: `awesome_wm_scripts/.config/scripts/rofi-*.sh` and `awesome_wm_scripts/.config/scripts/polybar-bluetooth-status.sh`
Original targets: `~/.config/scripts/`

These scripts are reference-only after every shell route moved to Quickshell and the generic `x11-display-profile.sh` backend replaced the Rofi display wrapper. They depend on Rofi or Polybar-era behavior and must not be catalogued, selected, linked, or called by active code.

Restoring any helper is a new migration: review its dependencies and mutation behavior, move only the required source back into an active package, update active callers deliberately, preview Stow changes, and obtain separate source/deployment approval.
