# Retired Rofi configuration

Retired: 2026-07-30
Original package: `rofi/`
Original target: `~/.config/rofi/`

This package is reference-only after the AwesomeWM/Quickshell cutover. Its themes depended on Rofi and the retired `rofi-*.sh` helpers now stored in `awesome_wm_scripts-archived/`.

It must not be registered in the Stow catalog, selected by a host profile, linked into `$HOME`, or launched by an active keybinding. Restoring it is a new migration: review the archived source, move it back to an unsuffixed package path, restore catalog/profile registration, preview Stow changes, and obtain separate deployment approval.
