#!/bin/bash

# note-preview: preview renderer used by note-tab-picker.

NOTES_DIR="${HOME}/Documents/notes"
PREVIEW_LINES=20

normalize_relative_path() {
  local input_path="$1"
  local normalized

  normalized="${input_path#./}"
  if [[ "$normalized" == "$NOTES_DIR/"* ]]; then
    normalized="${normalized#"$NOTES_DIR/"}"
  fi

  printf '%s\n' "$normalized"
}

main() {
  local file_arg="$1"
  local rel_path
  local abs_path

  rel_path="$(normalize_relative_path "$file_arg")"
  [[ -n "$rel_path" ]] || exit 0

  abs_path="$NOTES_DIR/$rel_path"
  if [[ ! -f "$abs_path" ]]; then
    printf 'File not found: %s\n' "$abs_path"
    exit 1
  fi

  bat --style=numbers -n --color=always --line-range ":$PREVIEW_LINES" "$abs_path"
}

main "$@"
