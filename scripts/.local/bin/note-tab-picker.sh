#!/bin/bash

# note-tab-picker: interactive file picker for `note` TAB completion.
#
# Behavior:
# - Lists markdown files in ~/Documents/notes recursively.
# - Sorts by mtime (newest first).
# - Returns a notes-relative path for the selected file.

NOTES_DIR="${HOME}/Documents/notes"
PICKER_HEADER='Ctrl-Y: Select | Ctrl-N/P: List Move | Ctrl-J/K: Preview Scroll'

list_recent_notes() {
  (
    cd "$NOTES_DIR" || exit 0
    fd -e md -t f . -X stat -c '%Y %n' | sort -rn | cut -d' ' -f2- | sed 's#^./##'
  )
}

[[ -d "$NOTES_DIR" ]] || exit 0

list_recent_notes | fzf \
  --prompt='NOTE> ' \
  --layout=reverse \
  --header="$PICKER_HEADER" \
  --preview='note-preview.sh {}' \
  --preview-window='right:60%:wrap' \
  --select-1 \
  --exit-0 \
  --bind='ctrl-j:preview-down' \
  --bind='ctrl-k:preview-up' \
  --bind='ctrl-y:accept' \
  --bind='enter:accept'
