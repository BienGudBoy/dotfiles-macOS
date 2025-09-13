#!/bin/bash
set -e

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
    defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
    defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
    defaults write com.apple.dock wvous-br-corner -int 1
    osascript -e 'tell application "System Events" to tell dock preferences to set autohide menu bar to true'

    sudo killall Finder
    sudo killall SystemUIServer
    sudo killall Dock
    sleep 2
    echo "macOS settings configured."
}

function initialize_sketchybar() {
    # Get font for sketchybar
    echo "Installing sketchybar-app-font..."
    curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.32/sketchybar-app-font.ttf -o $HOME/Library/Fonts/sketchybar-app-font.ttf

    echo "Installing sketchybar-app-font-bg..."
    ZIP_URL="https://github.com/SoichiroYamane/sketchybar-app-font-bg/archive/refs/tags/v0.0.11.zip"
    ZIP_FILE="$HOME/Downloads/sketchybar-app-font-bg.zip"
    EXTRACT_DIR="$HOME/Downloads/sketchybar-app-font-bg-0.0.11"

    curl -L $ZIP_URL -o $ZIP_FILE && \
    unzip $ZIP_FILE -d $HOME/Downloads && \
    cd $EXTRACT_DIR && \
    pnpm install && \
    pnpm run build:install && \
    rm -rf $ZIP_FILE $EXTRACT_DIR

    if ! pgrep -x "sketchybar" > /dev/null; then
        echo "Starting sketchybar..."
        /opt/homebrew/bin/sketchybar &
        # first start will take a while to compile lua scripts
        sleep 30
        echo "sketchybar started."
    else
        echo "sketchybar is already running."
    fi
}

if [[ "$1" == "--deploy-ci" ]]; then
    # Configure macOS settings
    configure_macos
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
    initialize_sketchybar
fi

if [[ "$1" == "--configure-macos" ]]; then
    configure_macos
fi