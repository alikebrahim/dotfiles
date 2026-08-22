#!/usr/bin/env python3
"""Publish lockscreen-safe XKB indicator and bell events as JSON lines.

This helper observes only the public Caps Lock indicator bit and XKB bell
notifications. It does not subscribe to keyboard input events or receive
keycodes.
"""

from __future__ import annotations

import ctypes
import ctypes.util
import json
import select
import signal
import sys

XKB_USE_CORE_KBD = 0x0100
XKB_INDICATOR_STATE_NOTIFY = 4
XKB_BELL_NOTIFY = 8
XKB_INDICATOR_STATE_NOTIFY_MASK = 1 << XKB_INDICATOR_STATE_NOTIFY
XKB_BELL_NOTIFY_MASK = 1 << XKB_BELL_NOTIFY
CAPS_LOCK_INDICATOR_NAME = b"Caps Lock"


class XEvent(ctypes.Union):
    _fields_ = [("type", ctypes.c_int), ("pad", ctypes.c_long * 24)]


class XkbAnyEvent(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.c_int),
        ("serial", ctypes.c_ulong),
        ("send_event", ctypes.c_int),
        ("display", ctypes.c_void_p),
        ("time", ctypes.c_ulong),
        ("xkb_type", ctypes.c_int),
        ("device", ctypes.c_uint),
    ]


def emit(payload: dict[str, object]) -> None:
    print(json.dumps(payload, separators=(",", ":")), flush=True)


def main() -> int:
    library = ctypes.util.find_library("X11")
    if not library:
        print("libX11 was not found", file=sys.stderr)
        return 2

    x11 = ctypes.CDLL(library)
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    x11.XConnectionNumber.argtypes = [ctypes.c_void_p]
    x11.XConnectionNumber.restype = ctypes.c_int
    x11.XPending.argtypes = [ctypes.c_void_p]
    x11.XPending.restype = ctypes.c_int
    x11.XNextEvent.argtypes = [ctypes.c_void_p, ctypes.POINTER(XEvent)]
    x11.XNextEvent.restype = ctypes.c_int
    x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    x11.XkbQueryExtension.argtypes = [
        ctypes.c_void_p,
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
    ]
    x11.XkbQueryExtension.restype = ctypes.c_int
    x11.XkbSelectEvents.argtypes = [
        ctypes.c_void_p,
        ctypes.c_uint,
        ctypes.c_uint,
        ctypes.c_uint,
    ]
    x11.XkbSelectEvents.restype = ctypes.c_int
    x11.XkbGetNamedIndicator.argtypes = [
        ctypes.c_void_p,
        ctypes.c_ulong,
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
        ctypes.c_void_p,
        ctypes.POINTER(ctypes.c_int),
    ]
    x11.XkbGetNamedIndicator.restype = ctypes.c_int

    display = x11.XOpenDisplay(None)
    if not display:
        print("could not open the X display", file=sys.stderr)
        return 2

    running = True

    def stop(_signal_number: int, _frame: object) -> None:
        nonlocal running
        running = False

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    opcode = ctypes.c_int()
    event_base = ctypes.c_int()
    error_base = ctypes.c_int()
    major = ctypes.c_int(1)
    minor = ctypes.c_int(0)
    if not x11.XkbQueryExtension(
        display,
        ctypes.byref(opcode),
        ctypes.byref(event_base),
        ctypes.byref(error_base),
        ctypes.byref(major),
        ctypes.byref(minor),
    ):
        print("the XKB extension is unavailable", file=sys.stderr)
        x11.XCloseDisplay(display)
        return 2

    event_mask = XKB_INDICATOR_STATE_NOTIFY_MASK | XKB_BELL_NOTIFY_MASK
    if not x11.XkbSelectEvents(display, XKB_USE_CORE_KBD, event_mask, event_mask):
        print("could not subscribe to XKB indicator and bell events", file=sys.stderr)
        x11.XCloseDisplay(display)
        return 2

    caps_lock_atom = x11.XInternAtom(display, CAPS_LOCK_INDICATOR_NAME, 1)
    if not caps_lock_atom:
        print("the XKB Caps Lock indicator is unavailable", file=sys.stderr)
        x11.XCloseDisplay(display)
        return 2

    def caps_lock_active() -> bool:
        index = ctypes.c_int()
        state = ctypes.c_int()
        real_indicator = ctypes.c_int()
        found = x11.XkbGetNamedIndicator(
            display,
            caps_lock_atom,
            ctypes.byref(index),
            ctypes.byref(state),
            None,
            ctypes.byref(real_indicator),
        )
        if not found:
            raise RuntimeError("could not read the XKB Caps Lock indicator")
        return bool(state.value)

    try:
        current_caps = caps_lock_active()
        emit({"type": "caps", "active": current_caps})
        x11.XSync(display, 0)
        connection = x11.XConnectionNumber(display)

        while running:
            readable, _, _ = select.select([connection], [], [], 2.0)
            if not readable:
                observed_caps = caps_lock_active()
                if observed_caps != current_caps:
                    current_caps = observed_caps
                    emit({"type": "caps", "active": current_caps})
                continue

            while x11.XPending(display):
                event = XEvent()
                x11.XNextEvent(display, ctypes.byref(event))
                if event.type != event_base.value:
                    continue

                xkb_event = ctypes.cast(
                    ctypes.byref(event), ctypes.POINTER(XkbAnyEvent)
                ).contents
                if xkb_event.xkb_type == XKB_INDICATOR_STATE_NOTIFY:
                    observed_caps = caps_lock_active()
                    if observed_caps != current_caps:
                        current_caps = observed_caps
                        emit({"type": "caps", "active": current_caps})
                elif xkb_event.xkb_type == XKB_BELL_NOTIFY:
                    emit({"type": "rejected"})
    except (OSError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        return 1
    finally:
        x11.XCloseDisplay(display)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
