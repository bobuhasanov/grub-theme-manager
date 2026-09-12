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
TIMEOUT_ARG="${1:-10}"

# 1. Determine boot directory (/boot/grub vs /boot/grub2)
if [ -d "/boot/grub2" ] && [ ! -d "/boot/grub" ]; then
    BOOT_GRUB_DIR="/boot/grub2"
else
    BOOT_GRUB_DIR="/boot/grub"
fi
TARGET_DIR="${BOOT_GRUB_DIR}/themes/${THEME_NAME}"
GRUB_CONFIG="/etc/default/grub"
BACKUP_CONFIG="/etc/default/grub.original.bak"

# 2. Locate source theme directory portably
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

# 3. Privilege check & elevation
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

# Read existing GRUB_CMDLINE_LINUX_DEFAULT to safely preserve user flags (e.g. nvidia, resume)
EXISTING_CMDLINE=""
if [ -f "${GRUB_CONFIG}" ]; then
    EXISTING_CMDLINE=$(grep -E '^[[:space:]]*GRUB_CMDLINE_LINUX_DEFAULT=' "${GRUB_CONFIG}" | head -n 1 | sed -E 's/^[[:space:]]*GRUB_CMDLINE_LINUX_DEFAULT=["'\''](.*)["'\'']/\1/' || true)
fi

# Safely merge silent boot parameters without losing hardware/driver specific arguments
MERGED_CMDLINE=$(python3 -c "
import sys
existing = '''${EXISTING_CMDLINE}'''.strip()
silent_params = ['quiet', 'splash', 'loglevel=3', 'vt.global_cursor_default=0', 'systemd.show_status=0']
tokens = existing.split() if existing else []
for sp in silent_params:
    key = sp.split('=')[0]
    tokens = [t for t in tokens if not t.startswith(key + '=') and t != key]
    tokens.append(sp)
print(' '.join(tokens))
")

# Clean existing theme & timeout settings
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
cat << CFG >> "${GRUB_CONFIG}"
# macOS Obsidian Theme Settings
GRUB_THEME="${TARGET_DIR}/theme.txt"
GRUB_GFXMODE="1920x1080,auto"
GRUB_TIMEOUT=${TIMEOUT_ARG}
GRUB_TIMEOUT_STYLE="menu"
GRUB_DISABLE_OS_PROBER=false
GRUB_CMDLINE_LINUX_DEFAULT="${MERGED_CMDLINE}"
CFG

# 4. Suppress noisy early ACPI BIOS console messages
SYSCTL_CONF="/etc/sysctl.d/10-console-messages.conf"
if [ -d "/etc/sysctl.d" ]; then
    echo "kernel.printk = 3 4 1 3" > "${SYSCTL_CONF}"
    echo "==> Configured silent ACPI console logging in ${SYSCTL_CONF}"
fi

# 5. Early KMS for Intel Graphics (only if Intel GPU detected)
MODULES_FILE="/etc/initramfs-tools/modules"
if [ -f "${MODULES_FILE}" ]; then
    if ! grep -q "^i915" "${MODULES_FILE}" && lspci 2>/dev/null | grep -iq "VGA.*Intel"; then
        echo "i915" >> "${MODULES_FILE}"
        echo "==> Configured Intel i915 early KMS module."
    fi
fi

# 6. Restore rock-solid stable Plymouth splash if available
if [ -f "/usr/share/plymouth/themes/mint-logo/mint-logo.plymouth" ]; then
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/mint-logo/mint-logo.plymouth 2>/dev/null || true
fi

# 7. Universal GRUB Generation across distros
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
else
    echo "Warning: Neither update-grub nor grub-mkconfig was found in PATH." >&2
fi

# 8. Update initramfs if tool exists
if command -v update-initramfs >/dev/null 2>&1; then
    echo "==> Updating initramfs..."
    update-initramfs -u
fi

echo "=================================================="
echo " macOS Obsidian GRUB 2 Theme Successfully Applied!"
echo " Resolution: 1920x1080 Native FHD"
echo " Timeout: ${TIMEOUT_ARG} seconds"
echo " Theme path: ${TARGET_DIR}/theme.txt"
echo " Silent Boot: ACPI spam suppressed, kernel flags preserved"
echo "=================================================="
