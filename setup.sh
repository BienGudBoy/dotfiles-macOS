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

function configure_macos() {
    echo "Configuring macOS settings..."
    defaults write NSGlobalDomain _HIHideMenuBar -int 1
    defaults write com.apple.dock autohide -bool true
    defaults write -g NSWindowShouldDragOnGesture -bool true
    defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
    defaults write com.apple.spaces "spans-displays" -bool true
    defaults write com.apple.dock "mru-spaces" -bool false
    defaults write com.apple.dock "show-recents" -bool true
    defaults write com.apple.finder "CreateDesktop" -bool false
    defaults write com.apple.dock "expose-group-apps" -bool false
    defaults write NSGlobalDomain "AppleSpacesSwitchOnActivate" -bool true
    defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

    killall SystemUIServer
    killall Dock
    sleep 2
    echo "macOS settings configured."
}

if [[ "$1" == "--deploy-ci" ]]; then
    # get SIP status
    csrutil status
    # get current nvram boot-args
    nvram boot-args
    # copy dotfiles
    echo "Deploying dotfiles..."
    mkdir -p ~/.config
    rsync -av --exclude='.git/' --exclude='setup.sh' ./ ~/.config/
    check_brew_install
    echo "Installing dependencies from Brewfile..."
    if ! brew bundle --file="$HOME/.config/Brewfile"; then
        echo "Failed to install dependencies from Brewfile."
        exit 1
    fi
    echo "Dependencies installed successfully."
fi

if [[ "$1" == "--configure-macos" ]]; then
    configure_macos
fi