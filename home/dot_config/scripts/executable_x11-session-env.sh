#!/bin/bash
set -euo pipefail

# Normalize the AwesomeWM/X11 session environment after logging in from a
# system that may also run GNOME/Wayland. This prevents Electron/Chromium/Qt
# apps from seeing stale Wayland hints while making DBus/systemd launches use
# the same X11 session values as Awesome.

unset WAYLAND_DISPLAY
unset ELECTRON_OZONE_PLATFORM_HINT
unset OZONE_PLATFORM
unset MOZ_ENABLE_WAYLAND

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=awesome
export DESKTOP_SESSION=awesome
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export CLUTTER_BACKEND=x11

# Keep these only if the display manager/session already provided them.
# They are required by GUI apps launched through DBus/systemd activation.
export DISPLAY="${DISPLAY:-:0}"
if [[ -n ${XAUTHORITY:-} ]]; then
  export XAUTHORITY
fi
if [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
  export DBUS_SESSION_BUS_ADDRESS
fi

vars=(
  DISPLAY
  XAUTHORITY
  XDG_SESSION_TYPE
  XDG_CURRENT_DESKTOP
  DESKTOP_SESSION
  GDK_BACKEND
  QT_QPA_PLATFORM
  CLUTTER_BACKEND
  DBUS_SESSION_BUS_ADDRESS
)

systemctl --user import-environment "${vars[@]}" 2>/dev/null || true
dbus-update-activation-environment --systemd "${vars[@]}" 2>/dev/null || true

# Explicitly remove Wayland hints from the systemd user manager environment when
# systemd is new enough to support unset-environment.
systemctl --user unset-environment \
  WAYLAND_DISPLAY \
  ELECTRON_OZONE_PLATFORM_HINT \
  OZONE_PLATFORM \
  MOZ_ENABLE_WAYLAND 2>/dev/null || true
