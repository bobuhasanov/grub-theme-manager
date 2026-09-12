#!/usr/bin/env bash
# ==============================================================================
# Startup & GRUB Theme Manager - Installer
# Author: bobuhasanov <boburhasanov6@gmail.com>
# Repository: https://github.com/bobuhasanov/grub-theme-manager
# License: MIT
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}${BOLD}"
echo "=================================================================="
echo "   Startup & GRUB Theme Manager                                   "
echo "   macOS Obsidian Dual-Boot Theme & 1:1 Live Interactive GUI       "
echo "   Author: bobuhasanov                                            "
echo "=================================================================="
echo -e "${RESET}"

# 1. Check dependencies
echo -e "${BLUE}[1/4] Checking dependencies...${RESET}"
DEPS=()

if ! command -v python3 >/dev/null 2>&1; then
    DEPS+=("python3")
fi

if ! python3 -c "import gi; gi.require_version('Gtk', '3.0')" 2>/dev/null; then
    DEPS+=("python3-gi" "gir1.2-gtk-3.0")
fi

if ! python3 -c "import cairo" 2>/dev/null; then
    DEPS+=("python3-cairo")
fi

if [ ${#DEPS[@]} -gt 0 ]; then
    echo -e "${YELLOW}--> Installing missing dependencies: ${DEPS[*]}...${RESET}"
    if [ "$EUID" -ne 0 ]; then
        sudo apt-get update -y && sudo apt-get install -y "${DEPS[@]}"
    else
        apt-get update -y && apt-get install -y "${DEPS[@]}"
    fi
else
    echo -e "${GREEN}✓ All required Python and GTK3 dependencies are satisfied.${RESET}"
fi

# 2. Install theme and helper scripts to ~/.local/share/grub-themes/
echo -e "\n${BLUE}[2/4] Installing theme assets and helper scripts...${RESET}"
THEMES_DEST="${HOME}/.local/share/grub-themes"
mkdir -p "${THEMES_DEST}/mac-obsidian"

cp -r "${SCRIPT_DIR}/themes/mac-obsidian/"* "${THEMES_DEST}/mac-obsidian/"
cp "${SCRIPT_DIR}/scripts/install-theme.sh" "${THEMES_DEST}/install-mac-obsidian.sh"
cp "${SCRIPT_DIR}/scripts/restore-default.sh" "${THEMES_DEST}/restore-default-grub.sh"
chmod +x "${THEMES_DEST}/install-mac-obsidian.sh" "${THEMES_DEST}/restore-default-grub.sh"
echo -e "${GREEN}✓ Theme assets installed to ${THEMES_DEST}/mac-obsidian${RESET}"

# 3. Install GUI application and desktop launcher
echo -e "\n${BLUE}[3/4] Installing Startup & GRUB Theme Manager application...${RESET}"
BIN_DEST="${HOME}/.local/bin"
mkdir -p "${BIN_DEST}"
cp "${SCRIPT_DIR}/bin/grub-theme-manager" "${BIN_DEST}/grub-theme-manager"
chmod +x "${BIN_DEST}/grub-theme-manager"

APP_DEST="${HOME}/.local/share/applications"
mkdir -p "${APP_DEST}"
cp "${SCRIPT_DIR}/desktop/grub-theme-manager.desktop" "${APP_DEST}/grub-theme-manager.desktop"

# Update desktop icon cache
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APP_DEST}" 2>/dev/null || true
fi
echo -e "${GREEN}✓ Installed GUI to ${BIN_DEST}/grub-theme-manager${RESET}"
echo -e "${GREEN}✓ Added launcher to Cinnamon / GNOME / XFCE application menu!${RESET}"

# 4. Optional instant system deployment
echo -e "\n${BLUE}[4/4] System configuration options...${RESET}"
echo -e "You can launch the GUI now from your Application Menu (under Administration or Preferences),"
echo -e "or run '${BOLD}grub-theme-manager${RESET}' in your terminal to view the 1:1 live simulator."
echo ""
echo -e "${YELLOW}Would you like to apply the theme to /boot/grub right now? [Y/n] ${RESET}"
read -r -t 15 REPLY || REPLY="n"
if [[ "${REPLY:-n}" =~ ^[Yy]$ ]]; then
    echo -e "--> Applying theme to system (authenticating)..."
    bash "${THEMES_DEST}/install-mac-obsidian.sh"
else
    echo -e "--> Skipped instant deployment. You can apply it anytime inside the GUI application!"
fi

echo -e "\n${GREEN}${BOLD}=================================================================="
echo "✓ Installation Complete! Launch 'Startup & GRUB Theme Manager'"
echo "==================================================================${RESET}\n"
