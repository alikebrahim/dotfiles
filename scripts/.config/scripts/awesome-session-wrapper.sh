#!/bin/bash

# awesome-session-wrapper.sh
# Robust X11 session foundation for AwesomeWM on Fedora/System76
# Moves environment hygiene earlier than rc.lua

# 1. Unset stale Wayland/Ozone variables to prevent Electron/GUI apps from
# attempting to use Wayland backends in an X11 session.
unset WAYLAND_DISPLAY
unset ELECTRON_OZONE_PLATFORM_HINT
unset OZONE_PLATFORM
unset MOZ_ENABLE_WAYLAND

# 2. Export explicit X11/Awesome session values
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=awesome
export DESKTOP_SESSION=awesome
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export CLUTTER_BACKEND=x11

# 3. Import cleaned values into systemd user and DBus activation environments.
# This ensures that services started by systemd or dbus-activation see the same
# environment as the WM and child processes.
systemctl --user import-environment \
    XDG_SESSION_TYPE \
    XDG_CURRENT_DESKTOP \
    DESKTOP_SESSION \
    GDK_BACKEND \
    QT_QPA_PLATFORM \
    CLUTTER_BACKEND \
    DISPLAY \
    XAUTHORITY

dbus-update-activation-environment --systemd \
    XDG_SESSION_TYPE \
    XDG_CURRENT_DESKTOP \
    DESKTOP_SESSION \
    GDK_BACKEND \
    QT_QPA_PLATFORM \
    CLUTTER_BACKEND \
    DISPLAY \
    XAUTHORITY

# 4. Exec Awesome
# Replace the wrapper process with Awesome so it inherits directly.
exec awesome
