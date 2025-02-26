# Reload ZSH configuration
reload_zsh() {
  echo "Reloading ZSH configuration..."
  source "$HOME/.zshrc"
  echo "ZSH configuration reloaded!"
}

# Show ZSH configuration files
list_zsh_configs() {
  echo "ZSH configuration files:"
  find "$HOME/.config/zsh" -type f -name "*.zsh" | sort
}