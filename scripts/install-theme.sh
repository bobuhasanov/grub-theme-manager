#!/usr/bin/env bash
# ==============================================================================
# macOS Obsidian GRUB 2 Theme & Silent Boot Installer
# Author: bobuhasanov <boburhasanov6@gmail.com>
# License: MIT
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"

THEME_NAME="mac-obsidian"
TARGET_DIR="/boot/grub/themes/${THEME_NAME}"
GRUB_CONFIG="/etc/default/grub"
BACKUP_CONFIG="/etc/default/grub.original.bak"

# Locate source theme directory portably
if [ -d "${PARENT_DIR}/themes/${THEME_NAME}" ]; then
    SRC_DIR="${PARENT_DIR}/themes/${THEME_NAME}"
elif [ -d "${HOME:-/root}/.local/share/grub-themes/${THEME_NAME}" ]; then
    SRC_DIR="${HOME:-/root}/.local/share/grub-themes/${THEME_NAME}"
elif [ -d "/usr/share/grub-themes/${THEME_NAME}" ]; then
    SRC_DIR="/usr/share/grub-themes/${THEME_NAME}"
else
    echo "Error: Cannot locate theme assets directory for ${THEME_NAME}" >&2
    exit 1
fi

# Privilege check & elevation
if [ "$EUID" -ne 0 ]; then
    if command -v zenity >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        PASS=$(zenity --password --title="Administrator Authentication" --text="Enter password to apply GRUB theme and silent boot configuration:" 2>/dev/null) || exit 1
        if [ -n "$PASS" ]; then
            echo "$PASS" | sudo -S bash "$0" "$@"
            exit $?
        fi
    elif command -v pkexec >/dev/null 2>&1; then
        exec pkexec bash "$0" "$@"
    elif command -v sudo >/dev/null 2>&1; then
        exec sudo bash "$0" "$@"
    else
        echo "Error: Administrator (root) privileges required." >&2
        exit 1
    fi
fi

echo "=================================================="
echo "==> 1. Installing macOS Obsidian GRUB 2 Theme..."
echo "=================================================="

# Create target theme directory
mkdir -p "${TARGET_DIR}"

# Copy theme assets (background, fonts, icons, theme.txt)
cp -r "${SRC_DIR}"/* "${TARGET_DIR}/"
chmod 755 "${TARGET_DIR}"
[ -d "${TARGET_DIR}/icons" ] && chmod 755 "${TARGET_DIR}/icons"
chmod 644 "${TARGET_DIR}"/*.* 2>/dev/null || true
[ -d "${TARGET_DIR}/icons" ] && chmod 644 "${TARGET_DIR}/icons"/*.* 2>/dev/null || true

# Backup original GRUB config if not yet backed up
if [ ! -f "${BACKUP_CONFIG}" ]; then
    cp "${GRUB_CONFIG}" "${BACKUP_CONFIG}"
    echo "==> Backed up original GRUB configuration to ${BACKUP_CONFIG}"
fi

# Clean existing settings
sed -i '/^GRUB_THEME=/d' "${GRUB_CONFIG}"
sed -i '/^#GRUB_THEME=/d' "${GRUB_CONFIG}"
sed -i '/^GRUB_GFXMODE=/d' "${GRUB_CONFIG}"
sed -i '/^#GRUB_GFXMODE=/d' "${GRUB_CONFIG}"
sed -i '/^GRUB_TIMEOUT=/d' "${GRUB_CONFIG}"
sed -i '/^GRUB_TIMEOUT_STYLE=/d' "${GRUB_CONFIG}"
sed -i '/^GRUB_DISABLE_OS_PROBER=/d' "${GRUB_CONFIG}"
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/d' "${GRUB_CONFIG}"
sed -i '/^# macOS Obsidian Theme Settings/d' "${GRUB_CONFIG}"

# Append optimized GRUB configuration
cat << 'CFG' >> "${GRUB_CONFIG}"
# macOS Obsidian Theme Settings
GRUB_THEME="/boot/grub/themes/mac-obsidian/theme.txt"
GRUB_GFXMODE="1920x1080,auto"
GRUB_TIMEOUT=10
GRUB_TIMEOUT_STYLE="menu"
GRUB_DISABLE_OS_PROBER=false
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 vt.global_cursor_default=0 systemd.show_status=0"
CFG

# 2. Suppress ACPI BIOS console spam
SYSCTL_CONF="/etc/sysctl.d/10-console-messages.conf"
if [ -d "/etc/sysctl.d" ]; then
    echo "kernel.printk = 3 4 1 3" > "${SYSCTL_CONF}"
    echo "==> Configured silent ACPI console logging in ${SYSCTL_CONF}"
fi

# 3. Early KMS for Intel / AMD Graphics
MODULES_FILE="/etc/initramfs-tools/modules"
if [ -f "${MODULES_FILE}" ]; then
    if ! grep -q "^i915" "${MODULES_FILE}" && lspci 2>/dev/null | grep -iq "VGA.*Intel"; then
        echo "i915" >> "${MODULES_FILE}"
        echo "==> Configured Intel i915 early KMS module."
    fi
fi

# 4. Restore rock-solid stable Plymouth splash if available
if [ -f "/usr/share/plymouth/themes/mint-logo/mint-logo.plymouth" ]; then
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/mint-logo/mint-logo.plymouth 2>/dev/null || true
fi

# 5. Update GRUB configuration
echo "==> Generating GRUB bootloader configuration (update-grub)..."
update-grub

# 6. Update initramfs if needed
if command -v update-initramfs >/dev/null 2>&1; then
    echo "==> Updating initramfs..."
    update-initramfs -u
fi

echo "=================================================="
echo " macOS Obsidian GRUB 2 Theme Successfully Applied!"
echo " Resolution: 1920x1080 Native FHD"
echo " Layout: Minimalist Floating Typography (Emerald Glow)"
echo " Silent Boot: ACPI spam suppressed, clean logo splash"
echo "=================================================="
