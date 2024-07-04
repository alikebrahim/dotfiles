#! /bin/env bash

set -e

APTPKGS=(curl git zsh jq stow xclip qemu qemu-system virt-manager google-chrome-stable tldr mpv sqlite3 imagemagick)
BUILD=(autoconf ninja-build gettext cmake unzip build-essential lowdown yacc)
LIBS=(libevent-dev libncurses-dev ffmpeg protobuf-compiler)

function apt {
  for pkg in "$@"; do
    sudo apt install -y $pkg
  done
}


# PPAs
# git
sudo add-apt-repository -y ppa:git-core/ppa
# wezterm
# curl -fSLO https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
# echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list

sudo apt update && sudo apt upgrade -y


apt "${APTPKGS[@]}"
apt "${BUILD[@]}"
apt "${LIBS[@]}"

# Languages
# go
mkdir -p ~/go/{pkg,bin,src}
cd ~/Downloads/
curl -sSLO https://go.dev/dl/go1.22.4.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.22.4.linux-amd64.tar.gz
rm go1.22.4.linux-amd64.tar.gz
# rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. $HOME/.cargo/env
# js (nvm+node)
# NOTE: nvm needs to be initialised at the end of the script (or somewhere)
PROFILE=/dev/null bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
. $HOME/.nvm/nvm.sh
#pyenv
curl https://pyenv.run | bash

# GOPKGS
export PATH="/usr/local/go/bin:$PATH"
export GOPATH="$HOME/go"
go install github.com/jesseduffield/lazygit@latest
export PATH="/usr/local/go/bin:$PATH"
export GOPATH="$HOME/go"
go install github.com/air-verse/air@latest
export PATH="/usr/local/go/bin:$PATH"
export GOPATH="$HOME/go"
go install github.com/go-delve/delve/cmd/dlv@latest
# CARGOPKGS
cargo install eza
cargo install zoxide
cargo install atuin
cargo install tokei
cargo install --locked bat


# wezterm
curl -LO https://github.com/wez/wezterm/releases/download/20240203-110809-5046fc22/wezterm-20240203-110809-5046fc22.Ubuntu22.04.deb
sudo apt install -y ./wezterm-20240203-110809-5046fc22.Ubuntu22.04.deb
rm ./wezterm-20240203-110809-5046fc22.Ubuntu22.04.deb

# Builds
# neovim
git clone https://github.com/neovim/neovim ~/.neovim
cd ~/.neovim
git checkout stable
make CMAKE_BUILD_TYPE=RelWithDebInfo && sudo make install

# tmux
git clone https://github.com/tmux/tmux.git ~/.tmux
cd ~/.tmux
sh autogen.sh
./configure
make && sudo make install

# btop
git clone https://github.com/aristocratos/btop.git ~/.btop
cd ~/.btop
make ADDFLAGS=-march=native && sudo make install

# fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --bin


# obsidian
mkdir -p ~/.local/bin && curl -fSLo ~/.local/bin/obsidian https://github.com/obsidianmd/obsidian-releases/releases/download/v1.6.5/Obsidian-1.6.5.AppImage
sudo chmod u+x ~/.local/bin/obsidian

# Repos
git clone git@github.com:alikebrahim/dotfiles.git ~/.dotfiles
git clone git@github.com:alikebrahim/obsidian-silo.git ~/Documents/obsidian
git clone git@github.com:alikebrahim/books.git ~/Documents/books

# Confg
cd ~/.dotfiles/
stow zsh nvim fzf tmux wezterm obsidian atuin
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

mkdir -p ~/.local/share/fonts/{JuliaMono,JetBrains}
cd ~/.local/share/fonts/JuliaMono/
curl -fSLO https://github.com/cormullion/juliamono/releases/download/v0.056/JuliaMono-ttf.tar.gz
tar xvf JuliaMono-ttf.tar.gz
cd ~/.local/share/fonts/JetBrains/
curl -fSLO https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip

tldr -u

fc-cache -r

chsh -s "$(which zsh)"
