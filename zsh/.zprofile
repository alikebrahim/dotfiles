# Auto-attach tmux on SSH login (exec replaces zsh — detach exits SSH immediately)
if [[ -o login ]] && [[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
  if tmux has-session -t ssh_tmux 2>/dev/null; then
    if tmux list-windows -t ssh_tmux -F '#W' 2>/dev/null | grep -qx 'system'; then
      exec tmux attach-session -t ssh_tmux:system
    else
      exec tmux new-window -t ssh_tmux -n system
    fi
  else
    exec tmux new-session -s ssh_tmux -n system
  fi
fi
