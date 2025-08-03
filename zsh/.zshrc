# direnv initialization (must come before instant prompt)
(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv export zsh)"

## Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# ENV VARS
# ********
## LOCAL BIN
export PATH="$HOME/.local/bin:$PATH"
## GO
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
## PYENV
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
## NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
## conda
export PATH="/home/alikebrahim/miniconda3/bin:$PATH"

# TOOL CONFIG
# ***********
## bat
export BAT_THEME="1337"
## fzf
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
export FZF_CTRL_R_OPTS="
  # --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"
export FZF_DEFAULT_OPTS='
  --color=hl:#ab3540,hl+:#b2ef6d,info:#bdbd77,marker:#87ff00
  --color=prompt:#ab3540,spinner:#ab3540,pointer:#ab3540,header:#a5f648
  --color=border:#262626,label:#aeaeae,query:#b2ef6d
  --preview-window="border-sharp" --prompt="> " --marker=">" --pointer="◆"
  --separator="─" --scrollbar="│" --layout="reverse" --info="right"
  --preview-window=wrap
  --bind "ctrl-j:preview-down"
  --bind "ctrl-k:preview-up"
  --bind "ctrl-y:accept"
  '

# ENV VARS (UNSUED)
# *****************
## Java environment
# export java_home="/usr/bin/java"
## sass
# export PATH="/opt/dart-sass:$PATH"
## # zig
# export PATH="$HOME/.local/bin/zig-linux-x86_64-0.13.0/:$PATH"


# Load completions
## This should precede plugins to avoid sytax-highlighting
## from overriding fzf-tab
autoload -Uz compinit && compinit 

# PLUGINS
# -------
zinit ice depth=1; zinit light romkatv/powerlevel10k
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting # workes best with fzf tab 
# zinit light jeffreytse/zsh-vi-mode
zinit light Aloxaf/fzf-tab #keep last

# SNIPPETS
# --------
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found
# zinit snippet OMZL::git.zsh
# zinit snippet OMZP::git
# zinit snippet OMZP::ubuntu

zinit cdreplay -q

# SOURCE PLUGIN CONFIG
# --------------------
## p10k
## To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
## fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# KEYBINDINGS
# -----------
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region


# HISTORY
# -------
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# COMPLETION STYLING
# ------------------
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' # Case-insensitive completion
zstyle ':completion:*' menu no # Don't show completion menu (needed for fzf-tab)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} # set list-colors to enable filename colorizing
zstyle ':fzf-tab:*' switch-group '<' '>' # switch group using `<` and `>`
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath' # Directory preview for cd completions
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always $realpath' # Directory preview for cd completions
zstyle ':completion:*:git-checkout:*' sort false # disable sort when completing `git checkout`
zstyle ':completion:*:descriptions' format '[%d]' # set descriptions format to enable group support
zstyle ':fzf-tab:*' fzf-flags --bind ctrl-y:accept # ctrl+y for accepting fzf-tab selection

# ALIASES
# -------
## Config aliases
alias zconf="vim ~/.zshrc"
alias zsrc="source ~/.zshrc"
alias vconf="vim ~/.config/nvim"
alias wezconf="vim ~/.config/wezterm/wezterm.lua"
alias tconf="vim ~/.tmux.conf"

## FILE SYSTEM NAVIGATION AND LISTING
# -----------------------------------
alias ls="eza"
alias ll="eza --color=always --long --git --icons=always"
alias la="eza --color=always --long --all --git --icons=always"
alias lt="eza --tree"

## Tool aliases
alias awk="gawk"
alias lg="lazygit"
alias cat="bat"
alias ntop="pipx run nvitop"
alias vim='nvim'
alias grep='grep --color'
alias bnvim='NVIM_APPNAME="nvim-blank" nvim'
alias lnvim='NVIM_APPNAME="nvim-lazy" nvim'

# SHELL INTEGRATIONS
# ------------------
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"
(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv hook zsh)"


# FUNCTIONS
# ---------
## fzf
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

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"

# pnpm
export PNPM_HOME="/home/alikebrahim/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

