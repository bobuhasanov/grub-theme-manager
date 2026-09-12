#!/usr/bin/env bash
# ==============================================================================
# Restore Default Standard GRUB Bootloader Configuration
# Author: bobuhasanov <boburhasanov6@gmail.com>
# License: MIT
# ==============================================================================

set -euo pipefail

# Determine boot directory (/boot/grub vs /boot/grub2)
if [ -d "/boot/grub2" ] && [ ! -d "/boot/grub" ]; then
    BOOT_GRUB_DIR="/boot/grub2"
else
    BOOT_GRUB_DIR="/boot/grub"
fi

GRUB_CONFIG="/etc/default/grub"
BACKUP_CONFIG="/etc/default/grub.original.bak"

if [ "$EUID" -ne 0 ]; then
    if command -v zenity >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        PASS=$(zenity --password --title="Administrator Authentication" --text="Enter password to restore default bootloader settings:" 2>/dev/null) || exit 1
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
echo "==> Restoring Default GRUB Configuration..."
echo "=================================================="

if [ -f "${BACKUP_CONFIG}" ]; then
    cp "${BACKUP_CONFIG}" "${GRUB_CONFIG}"
    echo "==> Restored configuration from ${BACKUP_CONFIG}"
else
    sed -i '/^GRUB_THEME=/d' "${GRUB_CONFIG}"
    sed -i '/mac-obsidian/d' "${GRUB_CONFIG}"
    echo "==> Removed theme parameters from ${GRUB_CONFIG}"
fi

echo "==> Generating GRUB bootloader configuration..."
if command -v update-grub >/dev/null 2>&1; then
    update-grub
elif command -v grub2-mkconfig >/dev/null 2>&1; then
    if [ -f /boot/grub2/grub.cfg ]; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
    elif [ -f /boot/efi/EFI/fedora/grub.cfg ]; then
        grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
    else
        grub2-mkconfig -o "${BOOT_GRUB_DIR}/grub.cfg"
    fi
elif command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o "${BOOT_GRUB_DIR}/grub.cfg"
fi

echo "=================================================="
echo " Default GRUB configuration successfully restored!"
echo "=================================================="
