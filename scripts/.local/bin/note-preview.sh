#!/bin/bash

# Configuration
PREVIEW_LINES=20

file="$1"
query="$2"

# Normalize candidate path to notes-relative form
file="${file#./}"
if [[ "$file" == "$HOME/Documents/notes/"* ]]; then
  file="${file#"$HOME/Documents/notes/"}"
fi

if [[ -z "$file" ]]; then
    exit 0
fi

# Ensure full path
filepath="$HOME/Documents/notes/$file"

if [[ ! -f "$filepath" ]]; then
    echo "File not found: $filepath"
    exit 1
fi

if [[ -n "$query" ]]; then
  # Find the first line number where the query appears in the file
  # using ripgrep (-n for line number, -m 1 for max 1 match)
  line=$(rg -n -m 1 -F -i -- "$query" "$filepath" 2>/dev/null | cut -d: -f1)
  
  if [[ -n "$line" && "$line" =~ ^[0-9]+$ ]]; then
    # Calculate start line to show some context above the match
    start_line=$((line - 5))
    [[ $start_line -lt 1 ]] && start_line=1
    
    end_line=$((start_line + PREVIEW_LINES - 1))
    
    bat --style=numbers -n --color=always \
      --highlight-line "$line" \
      --line-range "$start_line:$end_line" \
      "$filepath"
  else
    # Fallback if query not found in this specific file
    bat --style=numbers -n --color=always --line-range ":$PREVIEW_LINES" "$filepath"
  fi
else
  # Default preview without search query
  bat --style=numbers -n --color=always --line-range ":$PREVIEW_LINES" "$filepath"
fi
