# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ZSH configuration directory
ZSH_CONFIG_DIR="$HOME/.config/zsh"

# Core ZSH configuration files
for config_file in "$ZSH_CONFIG_DIR"/{zinit,env,history,keybindings,completions,integrations}.zsh; do
  [[ -f "$config_file" ]] && source "$config_file"
done

# Load all alias files
for alias_file in "$ZSH_CONFIG_DIR/aliases"/*.zsh; do
  [[ -f "$alias_file" ]] && source "$alias_file"
done

# Load all functions
for function_file in "$ZSH_CONFIG_DIR/functions"/*.zsh; do
  [[ -f "$function_file" ]] && source "$function_file"
done

# Load all plugin configurations
if [[ -d "$ZSH_CONFIG_DIR/plugins" ]]; then
  # Check if there are any .zsh files in the plugins directory
  plugin_files=("$ZSH_CONFIG_DIR/plugins"/*.zsh(N))
  if (( ${#plugin_files[@]} > 0 )); then
    for plugin_file in "${plugin_files[@]}"; do
      [[ -f "$plugin_file" ]] && source "$plugin_file"
    done
  fi
fi