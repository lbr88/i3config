#!/bin/bash

# i3 Config Installer Script
# This script attempts to install dependencies found in the i3 config file.

set -e

# Function to detect package manager
detect_pm() {
    if command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

PM=$(detect_pm)
echo "Detected package manager: $PM"

# Core packages found in config
PACKAGES=(
    "i3-wm"
    "terminator"
    "rofi"
    "feh"
    "picom"
    "dunst"
    "libnotify-bin" # Debian name, might vary
    "autorandr"
    "arandr"
    "nitrogen"
    "network-manager-gnome" # nm-applet
    "xfce4-power-manager"
    "flameshot"
    "keepassxc"
    "numlockx"
    "redshift-gtk"
    "playerctl"
    "xautolock"
    "brightnessctl"
    "pavucontrol"
    "moc"
    "pcmanfm"
    "python3-pip"
    "jq"
)

# Add distro-specific package names
if [ "$PM" == "pacman" ]; then
    # Arch/Manjaro specific names
    PACKAGES+=(
        "i3-scrot"
        "morc_menu"
        "pa-applet"
        "ibus"
        "gsfonts" # or urw-fonts
        "py3status"
        "python-pipx"
        "python-i3ipc"
    )
    # Note: some might be in AUR
elif [ "$PM" == "apt" ]; then
    # Debian/Ubuntu specific names
    PACKAGES+=(
        "i3-wm"
        "fonts-urw-base35"
        "ibus"
        "py3status"
        "pipx"
        "python3-i3ipc"
    )
    # Adjusting some names for apt
    PACKAGES=("${PACKAGES[@]/libnotify-bin/libnotify-bin}")
    PACKAGES=("${PACKAGES[@]/network-manager-gnome/network-manager-gnome}")
fi

echo "Installing system packages..."
if [ "$PM" == "pacman" ]; then
    sudo pacman -Syu --noconfirm "${PACKAGES[@]}"
elif [ "$PM" == "apt" ]; then
    sudo apt-get update
    sudo apt-get install -y "${PACKAGES[@]}"
elif [ "$PM" == "dnf" ]; then
    sudo dnf install -y "${PACKAGES[@]}"
else
    echo "Warning: Could not detect a supported package manager (pacman, apt, dnf)."
    echo "Please ensure the following packages are installed manually:"
    printf '%s\n' "${PACKAGES[@]}"
fi

# Python dependencies
echo "Installing Python dependencies..."

# Install i3-resurrect using pipx
if command -v pipx &> /dev/null; then
    echo "Installing i3-resurrect via pipx..."
    pipx install i3-resurrect
    pipx ensurepath
else
    echo "pipx not found. Skipping i3-resurrect installation."
fi

# Note: i3ipc is installed via system package (python3-i3ipc or python-i3ipc) 
# to ensure it is available for scripts running with the system python.

# Check for custom scripts/binaries referenced in config
echo "Checking for custom scripts referenced in config..."
MISSING_SCRIPTS=()

# List of custom scripts/paths to check
CUSTOM_PATHS=(
    "$HOME/bin/mon-conf.sh"
    "$HOME/git/private/clipboardgpt/replygpt.sh"
    "$HOME/git/private/clipboardgpt/grammargpt.sh"
    "jigglejiggle.sh"
    "i3exit"
    "i3-lockand"
    "blurlock"
    "i3-layout-manager"
)

for script in "${CUSTOM_PATHS[@]}"; do
    # Check if it's an absolute path
    if [[ "$script" == /* ]]; then
        if [ ! -f "$script" ]; then
            MISSING_SCRIPTS+=("$script")
        fi
    else
        # Check if it's in PATH
        if ! command -v "$script" &> /dev/null; then
            MISSING_SCRIPTS+=("$script (not in PATH)")
        fi
    fi
done

if [ ${#MISSING_SCRIPTS[@]} -ne 0 ]; then
    echo "Warning: The following scripts/programs referenced in your config were not found:"
    for s in "${MISSING_SCRIPTS[@]}"; do
        echo "  - $s"
    done
else
    echo "All referenced custom scripts found."
fi

# Make local scripts executable
chmod +x move-window-to-new-workspace.sh new-workspace.sh pack-workspaces.py

echo "Installation and check complete."
