#!/bin/bash

set -e

# [1/6] Install yay (if not installed)
if ! command -v yay &>/dev/null; then
    echo "[1/6] Installing yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
else
    echo "[1/6] yay is already installed."
fi

# [2/6] Install desired programs
echo "[2/6] Installing programs with yay..."

yay -S --noconfirm \
    firefox \
    fastfetch \
    mpv \
    zsh \
    spotify-adblock \
    cava \
    spicetify-cli

# Define some useful variables
INSTALL_DIR="$HOME/scripts"

# Ask user for zsh customization options
echo
echo "Would you like to install Zsh customizations? (y/n)"
read -r answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    # Install powerlevel10k and zsh-autosuggestions
    yay -S --noconfirm powerlevel10k zsh-autosuggestions
    echo "✓ Installed powerlevel10k and zsh-autosuggestions"

    # Check if Oh My Zsh is being used
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "✓ Oh My Zsh detected. Updating ~/.zshrc..."
        # Add powerlevel10k theme for Oh My Zsh
        sed -i 's|ZSH_THEME=".*"|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc
        # Add zsh-autosuggestions plugin
        echo 'plugins+=(zsh-autosuggestions)' >> ~/.zshrc
    else
        # Add powerlevel10k and autosuggestions manually if not using Oh My Zsh
        echo "source $ZSH/custom/themes/powerlevel10k/powerlevel10k.zsh-theme" >> ~/.zshrc
        echo "source $ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc
    fi
    echo "✓ Updated ~/.zshrc for powerlevel10k and zsh-autosuggestions"
fi

# [3/6] Set up GRUB theme
echo "[3/6] Cloning and applying GRUB theme..."

THEME_REPO="https://github.com/shvchk/poly-dark.git"
THEME_NAME="poly-dark"
THEME_DIR="/boot/grub/themes/$THEME_NAME"

# Clone the theme
git clone "$THEME_REPO" /tmp/$THEME_NAME

# Move theme to GRUB directory
sudo mkdir -p "$THEME_DIR"
sudo cp -r /tmp/$THEME_NAME/* "$THEME_DIR"

# Set GRUB_THEME line
if grep -q "GRUB_THEME=" /etc/default/grub; then
    sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DIR/theme.txt\"|" /etc/default/grub
else
    echo "GRUB_THEME=\"$THEME_DIR/theme.txt\"" | sudo tee -a /etc/default/grub
fi

# Regenerate GRUB config
sudo grub-mkconfig -o /boot/grub/grub.cfg

# [4/6] Apply Firefox CSS and settings
echo "[4/6] Cloning and applying Firefox configuration..."

CSS_REPO="https://github.com/KD-Shadow/firefox.git"
FIREFOX_PROFILE=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name "*.default-release" | head -n 1)
CONFIG_DIR="$HOME/.config"

git clone "$CSS_REPO" /tmp/firefox

if [ -d "$FIREFOX_PROFILE" ]; then
    cp -r /tmp/firefox/chrome "$FIREFOX_PROFILE/"
    cp /tmp/firefox/user.js "$FIREFOX_PROFILE/"
    echo "✓ chrome and user.js copied to $FIREFOX_PROFILE"
else
    echo "⚠️ Firefox profile not found. Skipping Firefox config."
fi

cp -r /tmp/firefox/startup-page "$CONFIG_DIR/"
echo "✓ startup-page copied to $CONFIG_DIR"

# [5/6] Setup Spicetify
echo "[5/6] Setting up Spicetify..."

# Permissions
sudo chmod a+wr /opt/spotify
sudo chmod a+wr /opt/spotify/Apps -R

# Init Spicetify
spicetify backup apply

# Clone themes
echo "[+] Cloning Spicetify themes..."
git clone --depth=1 https://github.com/spicetify/spicetify-themes.git /tmp/spicetify-themes

mkdir -p ~/.config/spicetify/Themes
cp -r /tmp/spicetify-themes/* ~/.config/spicetify/Themes/
echo "✓ Themes installed to ~/.config/spicetify/Themes"

# Ask user to pick a theme
echo
echo "🎨 Available Spicetify themes:"
ls ~/.config/spicetify/Themes | grep -v LICENSE
echo
read -p "Enter the name of the theme you want to use: " selected_theme

# Show available color schemes for the theme
SCHEMES_PATH="$HOME/.config/spicetify/Themes/$selected_theme/color.ini"

if [ -f "$SCHEMES_PATH" ]; then
    echo "🎨 Found one colorscheme: default"
    selected_scheme="default"
else
    SCHEMES_DIR="$HOME/.config/spicetify/Themes/$selected_theme/color-schemes"
    if [ -d "$SCHEMES_DIR" ]; then
        echo "🎨 Available color schemes for $selected_theme:"
        schemes=($(ls "$SCHEMES_DIR" | sed 's/.ini//'))
        select scheme in "${schemes[@]}"; do
            selected_scheme="$scheme"
            break
        done
    else
        echo "⚠️ No color schemes found for $selected_theme. Using default."
        selected_scheme="default"
    fi
fi

# Apply theme and color scheme
spicetify config current_theme "$selected_theme"
spicetify config color_scheme "$selected_scheme"
spicetify apply

echo "✓ Applied Spicetify theme: $selected_theme ($selected_scheme)"

# [6/6] Setup Spicetify Adblock extension
echo "[6/6] Setting up Spicetify Adblock extension..."

EXT_DIR="$HOME/.config/spicetify/Extensions"
mkdir -p "$EXT_DIR"

curl -sLo "$EXT_DIR/adblock.js" https://raw.githubusercontent.com/spicetify/spicetify-cli/master/Extensions/adblock.js

spicetify config extensions adblock.js
spicetify apply

echo "✓ Adblock extension installed and enabled for Spotify"

# [7/6] LightDM installation and setup
echo "[7/6] Do you want to install LightDM and related packages? (y/n)"
read -r answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    # Install LightDM and Greeter packages
    yay -S --noconfirm lightdm lightdm-gtk-greeter lightdm-theme-neon-bin
    echo "✓ Installed LightDM, lightdm-gtk-greeter, and lightdm-theme-neon-bin."

    # Enable and start LightDM service
    sudo systemctl enable lightdm.service --now
    echo "✓ LightDM service started and enabled."

    # Optionally, you can add LightDM greeter configuration here
    echo "✓ Configuring LightDM greeter theme..."
    sudo sed -i 's|#greeter-session=.*|greeter-session=lightdm-gtk-greeter|' /etc/lightdm/lightdm.conf
    sudo sed -i 's|#theme-name=.*|theme-name=Adwaita|' /etc/lightdm/lightdm-gtk-greeter.conf

    # If you want to use LightDM Neon (or configure its theme)
    echo "✓ Setting up LightDM Neon theme..."
    sudo sed -i 's|#theme-name=.*|theme-name=lightdm-neon|' /etc/lightdm/lightdm-gtk-greeter.conf
fi
    echo "Cloning wallpapers...."
    git clone https://github.com/KD-Shadow/wallpapers.git

# 🎉 All Done!
echo "Setup complete, sh4dow. Enjoy your riced system!"

