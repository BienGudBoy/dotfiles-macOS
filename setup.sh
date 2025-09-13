#!/bin/bash

function check_brew_install() {
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo "Homebrew is already installed."
    fi
}

if [[ "$1" == "--deploy-ci" ]]; then
    # get SIP status
    csrutil status
    # get current nvram boot-args
    nvram boot-args
    # copy dotfiles
    echo "Deploying dotfiles..."
    mkdir -p ~/.config
    rsync -av --exclude='.git/' --exclude='setup.sh' --exclude='Brewfile' ./ ~/.config/
    check_brew_install
    echo "Installing dependencies from Brewfile..."
    if ! brew bundle --file="$HOME/.config/Brewfile"; then
        echo "Failed to install dependencies from Brewfile."
        exit 1
    fi
    echo "Dependencies installed successfully."
fi