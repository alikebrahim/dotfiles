# Xvfb visual proof — isolated Omarchy/X11 milestone

Captured on 2026-07-26 from `tests/xvfb/visual-proof.qml` on an isolated
1920×1080 Xvfb display. All displayed service state comes from fixture
responses. No screenshot was captured from `DISPLAY=:0`, and no host control
mutation was enabled.

## Captures

| File | Panel | Pixel diversity |
|---|---|---:|
| `audio.png` | Audio hero, volume slider, current output | 3,133 colors |
| `network.png` | Network hero, Wi-Fi toggle, manager affordance | 3,870 colors |
| `bluetooth.png` | Bluetooth hero, adapter toggle, connected device | 3,893 colors |
| `display.png` | Brightness hero and slider | 2,984 colors |
| `power.png` | Battery hero, progress, equal profile buttons | 4,325 colors |

Every image is 1920×1080. The color counts reject an all-black or blank capture.

## Acceptance result

The images demonstrate:

- one continuous 26px translucent Omarchy-style bar rather than separate pills;
- Awesome tags and focused title at left, independently centered clock, and
  Bluetooth → Network → Audio → Display → Power status order at right;
- one 380px control-specific popup at a time;
- hero icon/title/metadata, separator, uppercase section, and control-state
  hierarchy adapted from Omarchy's shared UI components;
- content-fitted card heights with no fixed blank lower region;
- a passive styled OSD at the bottom center;
- rendered Nerd Font glyphs, readable contrast, and no visible clipping.

Automated image QA separately inspected Audio, Network, and Power and found no
missing glyphs, clipping, overlap, plain/default Qt styling, or excess panel
space. The functional Xvfb suite and production-composition probe provide the
non-visual behavior evidence; these PNGs are presentation evidence only.

## Historical boundary

This directory proves the isolated visual milestone and remains presentation
evidence only. Live AwesomeWM integration, primary-output placement, and the
Alt+Space handoff were completed later and are tracked in
`../project-status.md`. Native device/system mutations remain separately gated.
