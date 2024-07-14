# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

CASE_SENSITIVE="true"
HYPHEN_INSENSITIVE="true"
# ENABLE_CORRECTION="true"

zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' frequency 13

# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git 
  golang 
  python 
  ubuntu 
  zsh-syntax-highlighting
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# User configuration

## Keybindings section
bindkey -e
bindkey '^[[7~' beginning-of-line                               # Home key
bindkey '^[[H' beginning-of-line                                # Home key
if [[ "${terminfo[khome]}" != "" ]]; then
  bindkey "${terminfo[khome]}" beginning-of-line                # [Home] - Go to beginning of line
fi
bindkey '^[[8~' end-of-line                                     # End key
bindkey '^[[F' end-of-line                                      # End key
if [[ "${terminfo[kend]}" != "" ]]; then
  bindkey "${terminfo[kend]}" end-of-line                       # [End] - Go to end of line
fi
bindkey '^[[2~' overwrite-mode                                  # Insert key
bindkey '^[[3~' delete-char                                     # Delete key
bindkey '^[[C'  forward-char                                    # Right key
bindkey '^[[D'  backward-char                                   # Left key
bindkey '^[[5~' history-beginning-search-backward               # Page up key
bindkey '^[[6~' history-beginning-search-forward                # Page down key

# Navigate words with ctrl+arrow keys
bindkey '^[Oc' forward-word                                     #
bindkey '^[Od' backward-word                                    #
bindkey '^[[1;5D' backward-word                                 #
bindkey '^[[1;5C' forward-word                                  #
bindkey '^H' backward-kill-word                                 # delete previous word with ctrl+backspace
bindkey '^[[Z' undo                                             # Shift+tab undo last action

# App keybinds
# zle -N atuin-search
# bindkey '^r' atuin-search

# Preferred editor for local and remote sessions
 if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
 else
   export EDITOR='nvim'
 fi

# For a full list of active aliases, run `alias`.
#
# Aliases
alias zconf="vim ~/.zshrc"
alias zsrc="source ~/.zshrc"
alias vconf="vim ~/.config/nvim"
alias wezconf="vim ~/.config/wezterm/wezterm.lua"
alias tconf="vim ~/.tmux.conf"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias ls="eza"
alias ll="eza --color=always --long --git --icons=always"
alias lt="eza -Tree"
alias vim="nvim"
alias awk="gawk"
alias lg="lazygit"
alias cat="bat"
alias cd="z"
alias podman="nocorrect podman"

# Envs
# GOPATH
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export GOPATH="$HOME/go"
# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
# java environment
export JAVA_HOME="/usr/bin/java"
# sass
export PATH="/opt/dart-sass:$PATH"
# .local bin
export PATH="$HOME/.local/bin:$PATH"

# plugins
source /home/alikebrahim/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Commandline utilities
# atuin
eval "$(atuin init zsh)"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
export FZF_DEFAULT_OPTS='
  --color=hl:#ab3540,hl+:#b2ef6d,info:#bdbd77,marker:#87ff00
  --color=prompt:#ab3540,spinner:#ab3540,pointer:#ab3540,header:#a5f648
  --color=border:#262626,label:#aeaeae,query:#b2ef6d
  --preview-window="border-sharp" --prompt="> " --marker=">" --pointer="◆"
  --separator="─" --scrollbar="│" --layout="reverse" --info="right"
  --preview-window=wrap
  --bind "ctrl-j:preview-down"
  --bind "ctrl-k:preview-up"
  --bind "ctrl-d:preview-page-down"
  --bind "ctrl-u:preview-page-up"
  '

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo \${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

source $HOME/.config/zsh/fzf-git.sh/fzf-git.sh #fzf git integration

# bat
export BAT_THEME="1337"
# zoxide
eval "$(zoxide init zsh)"
# wezterm
export PATH="$PATH:$HOME/.wezterm/bin"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
