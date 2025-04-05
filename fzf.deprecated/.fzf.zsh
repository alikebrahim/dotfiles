# Setup fzf
# ---------
if [[ ! "$PATH" == */home/alikebrahim/repos/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/alikebrahim/.fzf/bin"
fi

eval "$(fzf --zsh)"
