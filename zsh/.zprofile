# Auto-attach tmux on SSH login with per-device grouped sessions.
#
# Each SSH client sends LC_TMUX_DEVICE=<hostname> via SetEnv in its SSH config
# (Fedora's default sshd AcceptEnv LANG LC_* passes it through).
# netmaster detects the device and creates a grouped session sharing windows
# with the main ssh_tmux session but with independent window selection.
#
# Fallback: if LC_TMUX_DEVICE is unset (legacy client), SSH_CLIENT IP is used.
#
# The system window uses remain-on-exit so accidental Ctrl-D/exit leaves a
# respawnable dead pane instead of destroying the landing window.
if [[ -o login ]] && [[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]] && (( ${+commands[tmux]} )); then
  MAIN="ssh_tmux"

  # Determine device identifier — SetEnv from client, or fall back to client IP
  if [[ -n "$LC_TMUX_DEVICE" ]]; then
    DEVICE="$LC_TMUX_DEVICE"
  else
    DEVICE="$(echo "${SSH_CLIENT%% *}" | tr '.' '-')"
  fi

  DEVICE_SESSION="${MAIN}-${DEVICE}"

  # Ensure main session exists with system window
  if ! tmux has-session -t "$MAIN" 2>/dev/null; then
    tmux new-session -d -s "$MAIN" -n system
  else
    if ! tmux list-windows -t "$MAIN" -F '#W' 2>/dev/null | grep -qx 'system'; then
      tmux new-window -d -t "$MAIN" -n system
    fi
  fi

  # Keep system window alive on accidental exit (respawnable dead pane)
  tmux set-window-option -t "${MAIN}:system" remain-on-exit on 2>/dev/null || true

  # Create device-specific grouped session (shares windows, independent view)
  if ! tmux has-session -t "$DEVICE_SESSION" 2>/dev/null; then
    tmux new-session -d -t "$MAIN" -s "$DEVICE_SESSION"
  fi

  exec tmux attach-session -t "$DEVICE_SESSION"
fi

# Added by Antigravity CLI installer
export PATH="/home/alikebrahim/.local/bin:$PATH"

# Termux (this phone): always attach to the persistent "main" tmux session.
# The tmux server keeps running after detach; tmux-continuum auto-saves every
# 15 min and auto-restores the last state (windows/panes/history/processes)
# whenever the tmux server starts (device boot via Termux:Boot, or first
# Termux open after a reboot). Set NO_TMUX=1 to skip auto-attach.
if [[ -o login ]] && [[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -n "$PREFIX" ]] && [[ -z "$SSH_TTY" ]] && [[ -z "$NO_TMUX" ]] && (( ${+commands[tmux]} )); then
  # Keep the tmux server alive after detach (Android otherwise kills Termux)
  (( ${+commands[termux-wake-lock]} )) && termux-wake-lock >/dev/null 2>&1
  # '=main' = exact match (plain 'main' would prefix-match e.g. 'main_hold')
  if ! tmux has-session -t '=main' 2>/dev/null; then
    tmux new-session -d -s main -c "$HOME"
  fi
  tmux attach-session -t '=main' 2>/dev/null || true
fi

# Secrets (API keys etc.): age-encrypted in the repo, decrypted to 0600 by
# chezmoi on hosts that have one. Absent file is a silent no-op.
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/secrets.env" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/secrets.env"
