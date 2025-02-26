# Shell integrations
if command -v fzf &>/dev/null; then
  eval "$(fzf --zsh)"
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init --cmd cd zsh)"
  eval "$(zoxide init zsh)"
fi

if command -v direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi

# fzf git integration
[[ -f "$HOME/.config/zsh/fzf-git.sh/fzf-git.sh" ]] && source "$HOME/.config/zsh/fzf-git.sh/fzf-git.sh"

# bat configuration
export BAT_THEME="1337"

# fzf configuration 
[[ -f "$HOME/.config/zsh/fzf.zsh" ]] && source "$HOME/.config/zsh/fzf.zsh"

# FZF configuration (fallback)
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh