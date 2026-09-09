KEYBIND COMPARISON BY LAYER — my dotfiles configs vs Omarchy defaults
=====================================================================

How to read / edit:
  Each function is one block:
      <id>  <function name>
        MINE     <my key / behavior>        (source file)
        OMARCHY  <omarchy key / behavior>
        STATUS   SAME | DIFF | MINE-ONLY | OMARCHY-ONLY
        NOTE     anything worth knowing
        CHANGE   <leave your instruction here, e.g. "keep mine", "use omarchy", "mine -> X", "omarchy -> Y">

Reply with the <id> (e.g. "T-1.3 -> mine") when you want edits applied.

SOURCES (verified):
  Mine tmux:     home/dot_tmux.conf                     (+ tmux defaults that stay active)
  Mine WM/apps:  home/dot_config/awesome/keys.lua       (AwesomeWM on servalws, modkey=Mod4)
  Omarchy tmux:  /usr/share/omarchy/config/tmux/tmux.conf  (seed; REMOVED on thinkpad - yours is active)
  Omarchy WM:    /usr/share/omarchy/default/hypr/bindings/*.lua  + "omarchy menu keybindings --print"
  Live Hyprland overrides on thinkpad: home/dot_config/hypr/bindings.lua -> ~/.config/hypr/bindings.lua
  Scope: tmux rows apply inside a tmux session. WM/apps rows: AwesomeWM = old (servalws), Hyprland = thinkpad now.
  NOTE on "MINE-ONLY"/"OMARCHY-ONLY": that side has no equivalent; decide whether to keep/adopt or ignore.

================================================================================
LAYER T — TMUX  (my tmux config vs omarchy's tmux seed)
================================================================================

T-1.1  Prefix
  MINE     C-q (C-b unbound)
  OMARCHY  C-Space (prefix2 C-b)
  STATUS   DIFF
  NOTE     Sets context for all tmux rows. Omarchy seed not active on thinkpad.
  CHANGE keep omarchy C-space

T-1.2  Send prefix
  MINE     C-q  -> send-prefix
  OMARCHY  C-Space -> send-prefix
  STATUS   DIFF
  CHANGE

T-1.3  Reload config
  MINE     C-q r
  OMARCHY  prefix + q  (C-Space then q - bound WITHOUT -n, so NOT a bare key; overrides default prefix-q = display-panes)
  STATUS   DIFF
  CHANGE

T-1.4  Show tmux keybinds
  MINE     C-q ?
  OMARCHY  ?  (popup via omarchy-menu-tmux-keybindings)
  STATUS   DIFF
  CHANGE keep omarchy

T-1.5  Create window
  MINE     C-q c   (tmux default)
  OMARCHY  c
  STATUS   SAME
  CHANGE

T-1.6  Rename window
  MINE     C-q ,   (tmux default)
  OMARCHY  r
  STATUS   DIFF
  CHANGE use prefix - , (mine)

T-1.7  Kill window
  MINE     C-q &   (tmux default)
  OMARCHY  k
  STATUS   DIFF
  CHANGE use omarchy's

T-1.8  Next / previous window
  MINE     M-{ } and S-Left / S-Right (no prefix)
  OMARCHY  M-Left / M-Right (no prefix)
  STATUS   DIFF
  NOTE     Both are no-prefix; adopt or keep.
  CHANGE use mine

T-1.9  Switch window by number
  MINE     C-q 1-9   (windows start at 1)
  OMARCHY  M-1 .. M-9 (no prefix)
  STATUS   DIFF
  CHANGE use omarchy's

T-1.10  Split pane - stacked
  MINE     C-q -
  OMARCHY  M-Enter (no prefix)  and prefix h
  STATUS   DIFF
  CHANGE use mine

T-1.11  Split pane - side by side
  MINE     C-q |
  OMARCHY  M-S-Enter (no prefix)  and prefix v
  STATUS   DIFF
  CHANGE

T-1.12  Focus pane left/down/up/right
  MINE     C-q h/j/k/l
  OMARCHY  C-M-Left/Up/Down/Right (no prefix)
  STATUS   DIFF
  CHANGE use mine

T-1.13  Resize pane
  MINE     C-q H/J/K/L (repeatable)
  OMARCHY  C-M-S-Arrows (no prefix)
  STATUS   DIFF
  NOTE     Fingers conflict: default jump key = C-q J (same as my resize J).
  CHANGE use omarchy. Use h/j/k/l instead of arrows

T-1.14  Kill pane
  MINE     C-q X (confirm) ; tmux default C-q x (no confirm)
  OMARCHY  x (prefix) ; M-Escape (no prefix)
  STATUS   DIFF
  CHANGE use omarchy

T-1.15  Zoom pane toggle
  MINE     C-q z / C-q m
  OMARCHY  -
  STATUS   MINE-ONLY
  CHANGE use mine

T-1.16  Rotate panes
  MINE     C-q R
  OMARCHY  -
  STATUS   MINE-ONLY
  CHANGE no need for this

T-1.17  Rename pane
  MINE     C-q T
  OMARCHY  -
  STATUS   MINE-ONLY
  CHANGE use mine

T-1.18  Respawn dead pane
  MINE     C-q C-r
  OMARCHY  -
  STATUS   MINE-ONLY
  CHANGE use mine

T-1.19  Window / session pickers + tmux-fzf
  MINE     C-q w (windows) ; C-q s (sessions) ; C-q f (fzf)
  OMARCHY  -
  STATUS   MINE-ONLY
  CHANGE use mine

T-1.20  Enter copy-mode
  MINE     C-q Enter (also default C-q [)
  OMARCHY  (tmux default)
  STATUS   MINE-ONLY
  CHANGE use mine

T-1.21  Copy-mode select / yank
  MINE     v = select ; y / Enter = copy via OSC52 to client
  OMARCHY  v = begin-selection ; y = copy (plain, no OSC52 pipe)
  STATUS   DIFF
  CHANGE use omarchy's

T-1.22  Search in buffer
  MINE     C-q /
  OMARCHY  -
  STATUS   MINE-ONLY
  CHANGE

T-1.23  Session management (create/rename/kill/switch)
  MINE     via C-q : command line only
  OMARCHY  C = new session ; R = rename ; K = kill ; N/P = next/prev ; M-Up/M-Down (no prefix)
  STATUS   OMARCHY extras
  CHANGE

T-1.24  Detach
  MINE     C-q d (tmux default)
  OMARCHY  -
  STATUS   MINE-ONLY
  CHANGE use mine

T-1.25  tmux-fingers (planned)
  MINE     C-q F = highlight/copy mode ; C-q G = jump mode
  OMARCHY  -
  STATUS   MINE-ONLY
  NOTE     Jump key deliberately moved off J (resize clash T-1.13).
  CHANGE where I have noted to use mine, inlucindg here, you will adapt the bidings to use omachy's prefix. So keep Prefix-F

================================================================================
LAYER W — WINDOW MANAGEMENT  (mine: AwesomeWM Mod4  |  omarchy: Hyprland SUPER)
================================================================================

W-2.1  Close window
  MINE     Mod4+q  (kill)
  OMARCHY  SUPER+W
  STATUS   DIFF
  CHANGE use mine (I believe the mod4 in mine is the same SUPER - confirm on this)

W-2.2  Close all windows
  MINE     -
  OMARCHY  CTRL+ALT+DELETE
  STATUS   OMARCHY-ONLY
  CHANGE

W-2.3  Maximize toggle
  MINE     Mod4+m
  OMARCHY  - (no maximize key; fullscreen instead, see W-2.4)
  STATUS   MINE-ONLY
  CHANGE  note below

W-2.4  Fullscreen (+variants)
  MINE     - (maximize only)
  OMARCHY  SUPER+F full ; SUPER+ALT+F full width ; SUPER+CTRL+F tiled fullscreen
  STATUS   OMARCHY-ONLY
  CHANGE change to SUPER+M full width and SUPER+ALT+M full (M instead of F following my config and reverse the full/full-width)

W-2.5  Toggle floating
  MINE     Mod4+t
  OMARCHY  SUPER+T
  STATUS   SAME (same key)
  CHANGE keep

W-2.6  Toggle titlebar
  MINE     Mod4+CTRL+SHIFT+t
  OMARCHY  -
  STATUS   MINE-ONLY (probably unneeded on hypr)
  CHANGE remove/ignore

W-2.7  Focus window left/down/up/right
  MINE     Mod4+h/l (spatial, across screens) ; Mod4+j/k (by direction)
  OMARCHY  SUPER+LEFT/RIGHT/UP/DOWN
  STATUS   DIFF
  NOTE     Mod4+h/j/k/l is my habit; SUPER+hjkl is free to add in bindings.lua.
  CHANGE add SUPER+h/j/k/l to move between windows

W-2.8  Focus next / previous window (cycle)
  MINE     - (only switcher menu W-4.4)
  OMARCHY  ALT+TAB / SHIFT+ALT+TAB  (also bound as "reveal on top" - duplicate)
  STATUS   OMARCHY-ONLY
  CHANGE keep omarchy

W-2.9  Move window with mouse (drag)
  MINE     Mod4 + Left button
  OMARCHY  SUPER + LEFT MOUSE BUTTON
  STATUS   SAME
  CHANGE

W-2.10  Resize window with mouse (drag)
  MINE     Mod4 + Right button
  OMARCHY  SUPER + RIGHT MOUSE BUTTON
  STATUS   SAME
  CHANGE

W-2.11  Layout control (cycle / toggle split / pseudo)
  MINE     Mod4+SHIFT+space = next layout
  OMARCHY  SUPER+J = toggle split ; SUPER+L = toggle layout ; SUPER+P = pseudo tiling
  STATUS   DIFF
  CHANGE SUPER+J and SUOER+L will have conflict with W-2.7. Change SUPER+J=SUPER+ALT+J,SUPER+L=SUPER+ALT+L: Note to me if these have any conflicts before

W-2.12  Scratchpad
  MINE     Mod4+`  (toggle terminal scratchpad)
  OMARCHY  SUPER+S (toggle) ; SUPER+ALT+S (move window there)
  STATUS   DIFF
  CHANGE Keep SUPER+S for a workspace scratchpad and create a SUPER+` for a terminal scratchpad that would open neovim with a tmp file

W-2.13  Pop window out (float & pin)
  MINE     -
  OMARCHY  SUPER+O
  STATUS   OMARCHY-ONLY
  CHANGE

W-2.14  Window grouping (hypr groups)
  MINE     - (Awesome tags played this role)
  OMARCHY  SUPER+G toggle ; SUPER+ALT+TAB / SUPER+SHIFT+ALT+TAB cycle ;
           SUPER+ALT+1..5 to group window N ; SUPER+ALT+UP/DOWN/LEFT/RIGHT move into group ;
           SUPER+ALT+G out of group ; SUPER+CTRL+LEFT/RIGHT group focus ; SUPER+ALT+mouse wheel
  STATUS   OMARCHY-ONLY
  CHANGE

W-2.15  Gaps / transparency / aspect / window width
  MINE     -
  OMARCHY  SUPER+SHIFT+BACKSPACE gaps ; SUPER+BACKSPACE transparency ;
           SUPER+CTRL+BACKSPACE square aspect ; SUPER+ALT+HOME save width ; SUPER+HOME restore width
  STATUS   OMARCHY-ONLY
  CHANGE

W-2.16  Keyboard window resize (12-key grid)
  MINE     - (tmux-style only)
  OMARCHY  SUPER+-/= with ALT (a little) / CTRL (a lot) / SHIFT (vertical):
           SUPER+- expand left | SUPER+= shrink left
           SUPER+SHIFT+- shrink up | SUPER+SHIFT+= expand down
  STATUS   OMARCHY-ONLY
  CHANGE

W-2.17  Scroll workspaces with wheel
  MINE     -
  OMARCHY  SUPER+mouse up/down
  STATUS   OMARCHY-ONLY
  CHANGE

================================================================================
LAYER WS — WORKSPACES & MONITORS
================================================================================

WS-3.1  Switch to workspace N
  MINE     Mod4+1..5  (5 workspaces, same index on all screens)
  OMARCHY  SUPER+1..9 / SUPER+0  (10 workspaces)
  STATUS   DIFF (count + semantics)
  CHANGE use omarchy's

WS-3.2  Move window to workspace N
  MINE     Mod4+SHIFT+1..5  (moves and follows)
  OMARCHY  SUPER+SHIFT+1..9/0 (move) ; SUPER+SHIFT+ALT+1..9/0 (move silently, no follow)
  STATUS   DIFF
  CHANGE use omarchy's

WS-3.3  Next / previous / former workspace
  MINE     Mod4+CTRL+j/k  (all screens together)
  OMARCHY  SUPER+TAB / SUPER+SHIFT+TAB / SUPER+CTRL+TAB
  STATUS   DIFF
  NOTE     My old Mod4+TAB = window switcher (W-4.4) - TAB means something else here.
  CHANGE mine. SUPER+CTRL+J/K

WS-3.4  Move client to next/prev workspace and follow
  MINE     Mod4+CTRL+SHIFT+j/k
  OMARCHY  - (only the numbered moves in WS-3.2)
  STATUS   MINE-ONLY
  CHANGE mine.

WS-3.5  Focus previous / next monitor (screen)
  MINE     Mod4+CTRL+h/l
  OMARCHY  CTRL+ALT+TAB / SHIFT+CTRL+ALT+TAB
  STATUS   DIFF
  CHANGE use omarchy's

WS-3.6  Move window to another monitor
  MINE     Mod4+SHIFT+h/l
  OMARCHY  no direct window-to-monitor bind; SUPER+SHIFT+ALT+UP/DOWN/LEFT/RIGHT moves the whole workspace
  STATUS   DIFF
  CHANGE ignore

================================================================================
LAYER A — LAUNCH & APPS & MENUS
================================================================================

A-4.1  Open terminal
  MINE     Mod4+RETURN  (wezterm)
  OMARCHY  SUPER+RETURN (ghostty)
  STATUS   SAME (key)
  CHANGE

A-4.2  Open browser
  MINE     Mod4+SHIFT+RETURN
  OMARCHY  SUPER+SHIFT+RETURN ; SUPER+SHIFT+B ; private SUPER+SHIFT+ALT+B
  STATUS   SAME (key)
  CHANGE

A-4.3  App launcher menu
  MINE     Mod4+SPACE
  OMARCHY  SUPER+SPACE (Omarchy menu) ; SUPER+ALT+SPACE (apps menu)
  STATUS   SAME concept
  CHANGE

A-4.4  Window switcher
  MINE     Mod4+TAB
  OMARCHY  - (ALT+TAB cycles windows; SUPER+TAB = next workspace)
  STATUS   DIFF - my Tab habit collides with Omarchy meaning of Tab
  CHANGE use omarchy's

A-4.5  Files / file manager
  MINE     Mod4+f  (nautilus)
  OMARCHY  SUPER+SHIFT+F ; current-dir SUPER+SHIFT+ALT+F
  STATUS   DIFF
  NOTE     Careful: SUPER+F alone = fullscreen.
  CHANGE use mine

A-4.6  Editor
  MINE     -
  OMARCHY  SUPER+SHIFT+N
  STATUS   OMARCHY-ONLY
  CHANGE

A-4.7  Keybindings help
  MINE     Mod4+s
  OMARCHY  SUPER+K ; tmux SUPER+ALT+K ; herdr SUPER+CTRL+K
  STATUS   DIFF
  CHANGE use omarchy's

A-4.8  Power / system menu
  MINE     Mod4+ESCAPE (power menu)
  OMARCHY  SUPER+ESCAPE (system menu) ; XF86PowerOff (power menu)
  STATUS   NEAR
  CHANGE use omarchy's

A-4.9  Display manager / display panel
  MINE     Mod4+p
  OMARCHY  SUPER+CTRL+D (display panel)
  STATUS   DIFF
  CHANGE use omarchy's

A-4.10  Proton Mail
  MINE     Mod4+e  (pinned ws3 right)
  OMARCHY  (email is HEY webapp: SUPER+SHIFT+E / new SUPER+SHIFT+ALT+E)
  STATUS   DIFF (different app)
  CHANGE I want to have mine with proton. I will install proton later

A-4.11  Discord
  MINE     Mod4+d  (pinned ws2 right)
  OMARCHY  -
  STATUS   MINE-ONLY
  CHANGE mine

A-4.12  WhatsApp
  MINE     Mod4+w  (pinned ws2 left)
  OMARCHY  SUPER+SHIFT+ALT+G
  STATUS   DIFF
  CHANGE mine

A-4.13  Network / Wi-Fi controls
  MINE     Mod4+SHIFT+w
  OMARCHY  SUPER+CTRL+W
  STATUS   DIFF
  CHANGE omarchy's

A-4.14  Bluetooth controls
  MINE     Mod4+SHIFT+b
  OMARCHY  SUPER+CTRL+B
  STATUS   DIFF
  CHANGE omarchy's

A-4.15  Audio controls
  MINE     Mod4+SHIFT+a
  OMARCHY  SUPER+CTRL+A
  STATUS   DIFF
  CHANGE omarchy's

A-4.16  Scratchpad terminal
  MINE     Mod4+`   (see also W-2.12)
  OMARCHY  SUPER+S (see also W-2.12)
  STATUS   DIFF
  CHANGE already answered above

A-4.17  Refresh monitors / UI
  MINE     Mod4+u
  OMARCHY  -
  STATUS   MINE-ONLY
  CHANGE omarchy's. ignore

A-4.18  Reload WM / quit WM
  MINE     Mod4+SHIFT+r reload ; Mod4+SHIFT+q quit
  OMARCHY  - (hypr: log out via menu)
  STATUS   MINE-ONLY
  CHANGE no need, follow omarchy

A-4.19  Web apps & extra apps (Omarchy-only)
  OMARCHY  SUPER+SHIFT+M Music(Spotify) | SUPER+SHIFT+ALT+M Music TUI
           SUPER+SHIFT+D Docker | SUPER+SHIFT+G Signal | SUPER+SHIFT+O Obsidian
           SUPER+SHIFT+W Omawrite | SUPER+SHIFT+SLASH Passwords(1Password)
           SUPER+CTRL+RETURN Herdr | SUPER+SHIFT+CTRL+A Agent
           SUPER+SHIFT+A ChatGPT | SUPER+SHIFT+ALT+A Grok | SUPER+SHIFT+C Calendar
           SUPER+SHIFT+Y YouTube | SUPER+SHIFT+CTRL+G Google Messages
           SUPER+SHIFT+P Google Photos | SUPER+SHIFT+S Google Maps
           SUPER+SHIFT+X X | SUPER+SHIFT+ALT+X X Post
           SHIFT+ALT+D Download video | SHIFT+ALT+L Copy URL from web app
           SUPER+ALT+BRACKETLEFT/RIGHT webcam overlay size
  STATUS   OMARCHY-ONLY (no mine equivalent; keep or rebind per app)
  CHANGE remove spotify, omawrite, google photos. For chatgpt=SUPER+CTRL+C, X=SUPER+CTRL+X, GROK=SUPER+CTRL+G, WHATSAPP=SUPER+CTRL+W. The rest keep omarchy defaults

================================================================================
LAYER S — MENUS, SHELL, SYSTEM, CLIPBOARD
================================================================================

S-5.1  Toggle bar / top bar
  MINE     Mod1+SPACE
  OMARCHY  SUPER+SHIFT+SPACE
  STATUS   DIFF
  CHANGE keep oarchy's

S-5.2  Lock system
  MINE     - (only idle xss-lock)
  OMARCHY  SUPER+CTRL+L
  STATUS   OMARCHY-ONLY
  CHANGE SUPER+CTRL+ALT+L

S-5.3  Universal copy / paste / cut
  MINE     - (terminal/tmux clipboard only)
  OMARCHY  SUPER+C / SUPER+V / SUPER+X
  STATUS   OMARCHY-ONLY
  NOTE     In terminals SUPER+C sends CTRL+Insert - check ghostty maps it.
  CHANGE keep omarchy's

S-5.4  Clipboard manager
  MINE     -
  OMARCHY  SUPER+CTRL+V
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.5  Emojis
  MINE     -
  OMARCHY  SUPER+CTRL+E
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.6  Calculator
  MINE     -
  OMARCHY  SUPER+CTRL+Q ; XF86Calculator
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.7  Notifications
  MINE     -
  OMARCHY  SUPER+COMMA dismiss last | SUPER+ALT+COMMA invoke last
           SUPER+CTRL+COMMA silence toggle | SUPER+SHIFT+COMMA dismiss all
           SUPER+SHIFT+ALT+COMMA history
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.8  Reminders
  MINE     -
  OMARCHY  SUPER+CTRL+R set | SUPER+CTRL+ALT+R show | SUPER+SHIFT+CTRL+R clear
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.9  Nightlight / idle lock
  MINE     -
  OMARCHY  SUPER+CTRL+N nightlight | SUPER+CTRL+I idle-lock
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.10  Bar panels 1..9
  MINE     -
  OMARCHY  SUPER+CTRL+1..9
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.11  Control panels (audio/bluetooth/display/hardware/power/activity/network)
  MINE     partial: Mod4+SHIFT+a/w/b, Mod4+p (see A-4.9, A-4.13..15)
  OMARCHY  SUPER+CTRL+A / B / D / H / P / T / W
  STATUS   DIFF (mine partial)
  CHANGE

S-5.12  Time / weather / battery / calendar widgets
  MINE     -
  OMARCHY  SUPER+CTRL+ALT+T time | +W weather | +B battery | +D calendar
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.13  Zoom in / reset zoom
  MINE     -
  OMARCHY  SUPER+CTRL+Z / SUPER+CTRL+ALT+Z
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.14  Monitor scaling
  MINE     -
  OMARCHY  SUPER+SLASH up | SUPER+ALT+SLASH down
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.15  Laptop display toggle / mirror
  MINE     -
  OMARCHY  SUPER+CTRL+DELETE toggle | SUPER+CTRL+ALT+DELETE mirror
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.16  Transcode
  MINE     -
  OMARCHY  SUPER+CTRL+PERIOD
  STATUS   OMARCHY-ONLY
  CHANGE

S-5.17  Menus (root / theme / background / toggle)
  MINE     -
  OMARCHY  SUPER+SPACE root | SUPER+SHIFT+CTRL+SPACE theme
           SUPER+CTRL+SPACE background | SUPER+CTRL+O toggle menu
  STATUS   OMARCHY-ONLY
  CHANGE

================================================================================
LAYER M — CAPTURE, MEDIA & HARDWARE KEYS
================================================================================

M-6.1  Screenshot interactive / region
  MINE     PRINT (flameshot gui) ; Mod4+SHIFT+s (region)
  OMARCHY  PRINT screenshot ; SUPER+CTRL+C capture menu
  STATUS   DIFF
  CHANGE keep omarchy

M-6.2  Screenshot full
  MINE     Mod4+PRINT
  OMARCHY  (available inside capture menu)
  STATUS   DIFF
  CHANGE follow omarchy

M-6.3  Screen recording
  MINE     -
  OMARCHY  ALT+PRINT
  STATUS   OMARCHY-ONLY
  CHANGE

M-6.4  Color picker
  MINE     -
  OMARCHY  SUPER+PRINT
  STATUS   OMARCHY-ONLY
  CHANGE

M-6.5  OCR text from screenshot
  MINE     -
  OMARCHY  SUPER+CTRL+PRINT
  STATUS   OMARCHY-ONLY
  CHANGE

M-6.6  Share / region actions
  MINE     -
  OMARCHY  SUPER+CTRL+S (plus RETURN/TAB/arrow layer while region is selected)
  STATUS   OMARCHY-ONLY
  CHANGE

M-6.7  Dictation
  MINE     -
  OMARCHY  SUPER+CTRL+X toggle | F9 push-to-talk (press/release)
  STATUS   OMARCHY-ONLY
  CHANGE

M-6.8  Volume up / down
  MINE     XF86AudioRaiseVolume / XF86AudioLowerVolume
  OMARCHY  same keys ; plus ALT+ same = +1% precise
  STATUS   SAME
  CHANGE

M-6.9  Mute / mic mute
  MINE     XF86AudioMute / XF86AudioMicMute
  OMARCHY  same keys ; plus SHIFT+XF86AudioMute = switch audio output
  STATUS   SAME
  CHANGE

M-6.10  Brightness up / down
  MINE     XF86MonBrightnessUp / XF86MonBrightnessDown
  OMARCHY  same keys ; plus ALT+ precise ; SHIFT+ max/min
  STATUS   SAME
  CHANGE

M-6.11  Media playback (prev/next/play/pause)
  MINE     -
  OMARCHY  XF86AudioPrev/Next/Play/Pause (+ ALT/SHIFT variants)
  STATUS   OMARCHY-ONLY
  CHANGE

M-6.12  Touchpad
  MINE     -
  OMARCHY  XF86TouchpadToggle / XF86TouchpadOn / XF86TouchpadOff
  STATUS   OMARCHY-ONLY
  CHANGE

M-6.13  Keyboard backlight
  MINE     -
  OMARCHY  XF86KbdBrightnessUp/Down / XF86KbdLightOnOff
  STATUS   OMARCHY-ONLY
  CHANGE

M-6.14  Eject
  MINE     -
  OMARCHY  XF86Eject
  STATUS   OMARCHY-ONLY
  CHANGE

================================================================================
CONFIG OWNERSHIP (which file sets each side)
================================================================================
  Area        Mine (dotfiles)                          Omarchy (system)
  tmux        home/dot_tmux.conf (+blue-matrix theme)  /usr/share/omarchy/config/tmux/tmux.conf (removed on thinkpad)
  WM keys     home/dot_config/awesome/keys.lua          /usr/share/omarchy/default/hypr/bindings/*.lua (read-only)
  Hyprland live overrides:  home/dot_config/hypr/bindings.lua -> ~/.config/hypr/bindings.lua (chezmoi, thinkpad-only)
  Ghostty     -                                        ~/.config/ghostty/config (Omarchy-managed local; not chezmoi yet)
  Rule: never edit /usr/share/omarchy. Hyprland overrides go in bindings.lua (loads AFTER defaults;
        call hl.unbind(KEY) before re-binding an Omarchy default).

================================================================================
KNOWN CONFLICTS & TRAPS (watch these when deciding)
================================================================================
  C1  tmux C-q J = resize  vs  tmux-fingers default jump C-q J  -> fingers jump moves to G
  C2  My Mod4+TAB = window switcher  vs  Omarchy SUPER+TAB = next workspace (ALT+TAB cycles)
  C3  My Mod4+q = close  vs  Omarchy SUPER+W = close  (decide which habit to keep)
  C4  My Mod4+f = files  vs  Omarchy SUPER+SHIFT+F = files (SUPER+F alone = fullscreen)
  C5  My Mod4+m = maximize  vs  Omarchy has none (fullscreen SUPER+F)
  C6  Omarchy SUPER+C/V universal copy inside ghostty/tmux (check CTRL+Insert; tmux y already works)
  C7  Omarchy ALT+TAB registered twice (focus + reveal) - unbind carefully
  C8  My tmux defaults still live: C-q x = kill pane (no confirm), C-q & kill window - decide overrides

--------------------------------------------------------------------------------
Generated for review - no keybind changes applied.

================================================================================
SESSION 2 — SANE CONFIG PROPOSAL & DECISION REPORT
================================================================================

> Proton Mail is now INSTALLED: AUR `proton-mail-bin 1.13.4-1`, binary
> `/usr/bin/proton-mail`, desktop entry `proton-mail.desktop`.
> (You wrote "proton-mainl-bin" — the real package name is `proton-mail-bin`.)

CORE PRINCIPLE — 3 clean layers, one rule each
----------------------------------------------
Your A-4.19 draft put apps into the system layer (SUPER+CTRL), which is the
mix you're unhappy with. Fix it with ONE consistent rule:

  Layer                Modifier                What lives there
  -------------------  ----------------------  ------------------------------
  Window management   SUPER (bare)            close, fullscreen, focus, float,
                                              workspaces, layout
  Apps                SUPER + SHIFT           every app/webapp, first letter
  System controls     SUPER + CTRL            audio, bluetooth, network,
                                              display, lock, panels, capture

  Variants (private browser, cwd, secondary app): SUPER + SHIFT + ALT + <letter>
  Help trio (see A):  SUPER+SHIFT+K (Hyprland), SUPER+ALT+K (tmux),
                      SUPER+CTRL+K (herdr)

This means NO app should ever sit on bare SUPER (WM layer) or SUPER+CTRL
(system layer). Apps are uniformly SUPER+SHIFT+<first letter>.


A. Keybindings help (SUPER+K) — the 3-way collision
---------------------------------------------------
FINDING
  SUPER+K must move (it becomes focus-up). Your proposal SUPER+CTRL+K is
  already "Herdr keybindings", and WS-3.3 also wanted it for prev-workspace.
  That is three things on one key.

SUGGESTION
  Put Hyprland help on SUPER+SHIFT+K. Nothing else has to move, and you get a
  clean help trio:
    SUPER+K        = focus up (window management)
    SUPER+SHIFT+K  = Hyprland keybindings help
    SUPER+ALT+K    = tmux keybindings        (unchanged) swap between herder. tmux=SUPER+CTRL+K
    SUPER+CTRL+K   = herdr keybindings       (unchanged)

  (K for help is also the vim convention — K = documentation/lookup.)

RESPONSE: agree. See note on tmux/herdr


B. Workspace next / previous (WS-3.3)
-------------------------------------
FINDING
  SUPER+CTRL+J/K puts workspace nav in the system layer and collides with
  Herdr + keybindings help.

SUGGESTION
  Keep Omarchy defaults: SUPER+TAB (next), SUPER+SHIFT+TAB (prev),
  SUPER+CTRL+TAB (former). Numbered workspaces stay SUPER+1..9/0.

RESPONSE: agree


C. Move window to next/prev workspace and follow (WS-3.4)
----------------------------------------------------------
SUGGESTION
  Drop it. Omarchy already covers this with SUPER+SHIFT+1..9/0 (move + follow)
  and SUPER+SHIFT+ALT+1..9/0 (move silently). Same outcome, fewer bindings.

RESPONSE: agree


D. Lock (S-5.2)
---------------
FINDING
  Omarchy already has SUPER+CTRL+L = Lock (L = Lock, correct system layer).
  You proposed SUPER+CTRL+ALT+L but nothing forces the move.

SUGGESTION
  Keep SUPER+CTRL+L.

RESPONSE: agree


E. Apps — mnemonic map (all on SUPER+SHIFT, first letter)
---------------------------------------------------------
  App          Key                Mnemonic / note
  -----------  -----------------  -----------------------------------------
  Terminal     SUPER+RETURN       keep (not a letter)
  Browser      SUPER+SHIFT+B      B = Browser //NOTE: keep as SUPER+SHIFT+RETURN
  Files        SUPER+SHIFT+F      F = Files (keep Omarchy default) //NOTE: keep SUPER+F
  Editor       SUPER+SHIFT+N      N = Neovim
  Proton Mail  SUPER+SHIFT+P      P = Proton (P freed by removing Photos) //NOTE: Change to E for email
  Discord      SUPER+SHIFT+D      D = Discord (Docker -> ALT+D)
  WhatsApp     SUPER+SHIFT+W      W = WhatsApp (W freed by removing Omawrite)
  ChatGPT      SUPER+SHIFT+C      C = ChatGPT (Calendar -> ALT+C)
  Grok         SUPER+SHIFT+G      G = Grok (Signal -> ALT+G)
  X            SUPER+SHIFT+X      X = X

  Collision resolutions (first-letter ties):
    Docker   vs Discord  ->  Discord SUPER+SHIFT+D,  Docker SUPER+SHIFT+ALT+D //NOTE: ingore. I don't need docker
    Calendar vs ChatGPT  ->  ChatGPT SUPER+SHIFT+C,  Calendar SUPER+SHIFT+ALT+C
    Signal   vs Grok     ->  Grok SUPER+SHIFT+G,     Signal SUPER+SHIFT+ALT+G // NOTE: remove signal, I dont need it

  Keep as Omarchy defaults (already mnemonic):
    Obsidian SUPER+SHIFT+O, YouTube SUPER+SHIFT+Y, Maps SUPER+SHIFT+S,
    Passwords SUPER+SHIFT+SLASH, X-Post SUPER+SHIFT+ALT+X,
    Browser-private SUPER+SHIFT+ALT+B, Files-cwd SUPER+SHIFT+ALT+F.

  Alternative (if you prefer Omarchy's native AI grouping on "A"):
    ChatGPT SUPER+SHIFT+A, Grok SUPER+SHIFT+ALT+A, Agent SUPER+SHIFT+CTRL+A.
    This is also consistent, just keyed on "A = AI" instead of first letters.

RESPONSE: Agree. See notes


F. Removals (confirm exact set)
-------------------------------
  Music (Spotify)   SUPER+SHIFT+M       -> remove
  Music TUI         SUPER+SHIFT+ALT+M   -> remove too? (also music) //NOTE: keep
  Omawrite          SUPER+SHIFT+W       -> remove (frees W for WhatsApp) //NOTE: remove
  Google Photos     SUPER+SHIFT+P       -> remove (frees P for Proton) //NOTE: remove

RESPONSE: see notes


G. Files — SUPER+F vs SUPER+SHIFT+F
-----------------------------------
FINDING
  Your A-4.5 wanted SUPER+F (old Awesome habit). But bare SUPER is the WM
  layer; apps belong on SUPER+SHIFT. SUPER+SHIFT+F is already Omarchy's
  default, and SUPER+F is now free (fullscreen moved to M).

SUGGESTION
  Keep SUPER+SHIFT+F for Files to preserve the layer rule.

RESPONSE: For files keep SUPER+F


H. Scratchpad terminal (SUPER+`)
--------------------------------
FINDING
  SUPER+` (code:49) is free, but "nvim with a tmp file" needs a small helper
  (launch + special-workspace window rule + toggle), not a plain keybind.

SUGGESTION
  Defer. Once the keybinds are settled I'll draft the helper as a follow-up.

RESPONSE: create the necessary. You can check the dotfiles for ideas, I have that setup with minisforoum hyprland


I. tmux under .config — restore?
--------------------------------
FINDING
  Do NOT restore the raw Omarchy seed. tmux 3.7 loads
  ~/.config/tmux/tmux.conf BEFORE ~/.tmux.conf, so restoring the seed would
  shadow your whole personal config (C-q prefix, TPM, OSC52, theme loader).
  The removal (home/dot_config/tmux/remove_tmux.conf) was correct.

SUGGESTION
  Keep the removal. If you later adopt the Omarchy C-Space prefix, we migrate
  your MERGED config to ~/.config/tmux/tmux.conf (separate, explicit task).

RESPONSE: agree. But as per my answers, it will be a mix. For instance the prefix will be CTRL+SPACE and the copy will follow omarchy. So fetch the original and adopt as per my notes. Where you cannot make a determination, you will report to me by updating this file (append notes at bottom)


J. Net changes I'll make to home/dot_config/hypr/bindings.lua (after your answers)
---------------------------------------------------------------------------------
  Unbind:
    SUPER+W            (was close window)
    SUPER+F            (was fullscreen)
    SUPER+ALT+F        (was full width)
    SUPER+J            (was toggle split)
    SUPER+L            (was workspace layout toggle)
    SUPER+K            (was keybindings help)
    SUPER+SHIFT+M      (Music / Spotify)
    SUPER+SHIFT+ALT+M  (Music TUI)
    SUPER+SHIFT+W      (Omawrite)
    SUPER+SHIFT+P      (Google Photos)
    SUPER+SHIFT+ALT+G  (old WhatsApp webapp)
    SUPER+SHIFT+A      (old ChatGPT)
    SUPER+SHIFT+ALT+A  (old Grok)
    (+ Docker/Calendar/Signal if you accept the tie-breaks in E)

  Bind (window management):
    SUPER+Q  close | SUPER+M full-width | SUPER+ALT+M full
    SUPER+H/J/K/L focus | SUPER+ALT+J toggle split | SUPER+ALT+L layout

  Bind (help):
    SUPER+SHIFT+K keybindings help

  Bind (apps):
    SUPER+SHIFT+P Proton | SUPER+SHIFT+D Discord | SUPER+SHIFT+W WhatsApp
    SUPER+SHIFT+C ChatGPT | SUPER+SHIFT+G Grok | SUPER+SHIFT+X X

  Keep unchanged: workspaces SUPER+1..9/0, SUPER+TAB prev/next,
  system SUPER+CTRL layer, tmux/herdr keybindings.


================================================================================
SESSION 3 — IMPLEMENTATION RECORD & OPEN QUESTIONS
================================================================================

APPLIED (Hyprland, home/dot_config/hypr/bindings.lua)
-----------------------------------------------------
  WM:     SUPER+Q close | SUPER+M full-width | SUPER+ALT+M full
          SUPER+H/J/K/L focus | SUPER+ALT+J split | SUPER+ALT+L layout
  Help:   SUPER+SHIFT+K Hyprland | SUPER+CTRL+K tmux | SUPER+ALT+K herdr
  Apps:   SUPER+F files | SUPER+SHIFT+E Proton | SUPER+SHIFT+D Discord
          SUPER+SHIFT+W WhatsApp | SUPER+SHIFT+C ChatGPT | SUPER+SHIFT+G Grok
          SUPER+SHIFT+ALT+C Calendar (X stays SUPER+SHIFT+X)
  Removed: Music(SUPER+SHIFT+M), Google Photos(SUPER+SHIFT+P),
           Omawrite(SUPER+SHIFT+W), Docker(SUPER+SHIFT+D), Signal(SUPER+SHIFT+G),
           HEY email + new email, old ChatGPT/Grok (SUPER+SHIFT+A / ALT+A),
           old WhatsApp (SUPER+SHIFT+ALT+G). Music TUI (SUPER+SHIFT+ALT+M) KEPT.
  Scratchpad: SUPER+` -> ~/.local/bin/scratch-term (nvim +startinsert
           /tmp/file<ts>) + window rule on special:scratchterm (floating).

APPLIED (tmux, home/dot_config/tmux/tmux.conf — NEW, thinkpad-only)
------------------------------------------------------------------
  Replaced the remove_tmux.conf target with a managed merged config.
  Base = Omarchy seed + your T-layer notes + TPM plugins (resurrect,
  continuum, fzf). Prefix C-Space. Validated with `tmux source-file` — clean.
  NOTE: ~/.tmux.conf is now SHADOWED on thinkpad (tmux 3.7 loads the XDG
  config first). It is still deployed to other hosts. Retiring it on thinkpad
  is optional — say the word.

OPEN QUESTIONS (my determinations where your notes were silent)
---------------------------------------------------------------
  1. THEME: I used Omarchy's inline blue status bar, NOT your blue-matrix
     loader (~/.tmux/theme.conf). Want blue-matrix back? Then I add
     `source-file ~/.tmux/theme.conf` and drop the inline theme.
     RESPONSE: ___
  2. TERMINAL: I used Omarchy's `tmux-256color` + RGB/clipboard, NOT your
     xterm-256color + OSC52 passthrough (copy is plain per your note).
     RESPONSE: ___
  3. RESIZE: `C-M-S-h/j/k/l` (no-prefix Ctrl+Alt+Shift). tmux accepted the
     syntax, but some terminals don't send C-M-S-letter distinctly — test in
     practice. Alternative: prefix H/J/K/L.
     RESPONSE: ___
  4. SEARCH (T-1.22): omitted (Omarchy has no search bind). Want prefix /
     copy-mode search back?
     RESPONSE: ___
  5. tmux-fingers F/G: left COMMENTED OUT (plugin not installed yet). Install
     the plugin, then I'll activate them.
     RESPONSE: ___
  6. Window prev/next: kept Omarchy M-Left/M-Right AND added your M-{/M-}/
     S-Left/S-Right. Remove the M-Left/M-Right duplicates?
     RESPONSE: ___
  7. detach-on-destroy: set `off` (Omarchy). Your old config used `on`.
     RESPONSE: ___

Fill in any RESPONSE fields above (or say "keep your determinations") and
I'll adjust.
