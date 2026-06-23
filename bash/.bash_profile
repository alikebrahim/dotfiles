# Source ~/.bashrc for interactive login shells.
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Auto-attach tmux on SSH login (exec replaces bash — detach exits SSH immediately).
# The system window uses remain-on-exit so accidental Ctrl-D/exit leaves a
# respawnable dead pane instead of destroying the landing window.
# Mirrors zsh/.zprofile behavior: login + interactive + SSH-only.
if [ -n "$SSH_TTY" ] && [ -z "$TMUX" ] && command -v tmux >/dev/null 2>&1; then
  if tmux has-session -t ssh_tmux 2>/dev/null; then
    if ! tmux list-windows -t ssh_tmux -F '#W' 2>/dev/null | grep -qx 'system'; then
      tmux new-window -d -t ssh_tmux -n system
    fi
  else
    tmux new-session -d -s ssh_tmux -n system
  fi

  tmux set-window-option -t ssh_tmux:system remain-on-exit on 2>/dev/null || true
  exec tmux attach-session -t ssh_tmux:system
fi
