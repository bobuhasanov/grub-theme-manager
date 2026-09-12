#!/usr/bin/env bash
# ==============================================================================
# Startup & GRUB Theme Manager - Universal Linux Installer
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
AUTO_APPLY=false

for arg in "$@"; do
    case "$arg" in
        -y|--yes) AUTO_APPLY=true ;;
    esac
done

echo -e "${CYAN}${BOLD}"
echo "=================================================================="
echo "   Startup & GRUB Theme Manager                                   "
echo "   macOS Obsidian Dual-Boot Theme & 1:1 Live Interactive GUI       "
echo "   Author: bobuhasanov                                            "
echo "=================================================================="
echo -e "${RESET}"

# 1. Check & Install Dependencies across Debian/Ubuntu, Fedora, Arch
echo -e "${BLUE}[1/4] Checking dependencies...${RESET}"
DEPS_NEEDED=false

if ! command -v python3 >/dev/null 2>&1; then
    DEPS_NEEDED=true
fi

if ! python3 -c "import gi; gi.require_version('Gtk', '3.0')" 2>/dev/null; then
    DEPS_NEEDED=true
fi

if ! python3 -c "import cairo" 2>/dev/null; then
    DEPS_NEEDED=true
fi

if [ "$DEPS_NEEDED" = true ]; then
    echo -e "${YELLOW}--> Missing required GTK3 / Python dependencies. Attempting auto-install...${RESET}"
    if command -v apt-get >/dev/null 2>&1; then
        SUDO_CMD=""
        [ "$EUID" -ne 0 ] && SUDO_CMD="sudo"
        $SUDO_CMD apt-get update -y && $SUDO_CMD apt-get install -y python3 python3-gi gir1.2-gtk-3.0 python3-cairo
    elif command -v dnf >/dev/null 2>&1; then
        SUDO_CMD=""
        [ "$EUID" -ne 0 ] && SUDO_CMD="sudo"
        $SUDO_CMD dnf install -y python3 python3-gobject gtk3 python3-cairo
    elif command -v pacman >/dev/null 2>&1; then
        SUDO_CMD=""
        [ "$EUID" -ne 0 ] && SUDO_CMD="sudo"
        $SUDO_CMD pacman -S --noconfirm python python-gobject gtk3 python-cairo
    else
        echo -e "${YELLOW}Notice: Please install Python 3, PyGObject (GTK3), and PyCairo using your system package manager.${RESET}"
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

# Set absolute executable path in desktop entry to ensure it launches reliably on all desktop environments
sed -i "s|^Exec=.*|Exec=${BIN_DEST}/grub-theme-manager|" "${APP_DEST}/grub-theme-manager.desktop"

# Update desktop icon cache
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APP_DEST}" 2>/dev/null || true
fi
echo -e "${GREEN}✓ Installed GUI to ${BIN_DEST}/grub-theme-manager${RESET}"
echo -e "${GREEN}✓ Added launcher to Cinnamon / GNOME / XFCE application menu!${RESET}"

# 4. Optional instant system deployment
echo -e "\n${BLUE}[4/4] System configuration options...${RESET}"
echo -e "You can launch the GUI now from your Application Menu (under Administration or Preferences),"
echo -e "or run '${BOLD}${BIN_DEST}/grub-theme-manager${RESET}' in your terminal to view the 1:1 live simulator."
echo ""

if [ "$AUTO_APPLY" = true ]; then
    echo -e "--> Auto-applying theme to system..."
    bash "${THEMES_DEST}/install-mac-obsidian.sh"
else
    echo -e "${YELLOW}Would you like to apply the theme to /boot/grub right now? [Y/n] ${RESET}"
    read -r -t 15 REPLY || REPLY="n"
    if [[ "${REPLY:-n}" =~ ^[Yy]$ ]]; then
        echo -e "--> Applying theme to system (authenticating)..."
        bash "${THEMES_DEST}/install-mac-obsidian.sh"
    else
        echo -e "--> Skipped instant deployment. You can apply it anytime inside the GUI application!"
    fi
fi

echo -e "\n${GREEN}${BOLD}=================================================================="
echo "✓ Installation Complete! Launch 'Startup & GRUB Theme Manager'"
echo "==================================================================${RESET}\n"
