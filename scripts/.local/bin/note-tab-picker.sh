#!/bin/bash

NOTES_DIR="${HOME}/Documents/notes"

if [[ ! -d "$NOTES_DIR" ]]; then
  exit 0
fi

notes_dir_q=$(printf '%q' "$NOTES_DIR")
recent_cmd="cd $notes_dir_q && fd -e md -t f . -X stat -c '%Y %n' | sort -rn | cut -d' ' -f2- | sed 's#^./##'"

eval "$recent_cmd" | fzf \
  --prompt="NOTE> " \
  --layout=reverse \
  --header='Ctrl-Y: Select | Ctrl-N/P: List Move | Ctrl-J/K: Preview Scroll' \
  --preview='note-preview.sh {} ""' \
  --preview-window=right:60%:wrap \
  --select-1 \
  --exit-0 \
  --bind='ctrl-j:preview-down' \
  --bind='ctrl-k:preview-up' \
  --bind='ctrl-y:accept' \
  --bind='enter:accept'
