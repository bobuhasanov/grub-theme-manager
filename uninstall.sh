#!/usr/bin/env bash
# ==============================================================================
# Startup & GRUB Theme Manager - Uninstaller
# Author: bobuhasanov <boburhasanov6@gmail.com>
# ==============================================================================

set -euo pipefail

echo "==> Uninstalling Startup & GRUB Theme Manager..."

# Restore default bootloader if installed
RESTORE_SCRIPT="${HOME}/.local/share/grub-themes/restore-default-grub.sh"
if [ -f "${RESTORE_SCRIPT}" ]; then
    echo "--> Restoring standard GRUB bootloader..."
    bash "${RESTORE_SCRIPT}" || true
fi

# Remove application files
rm -f "${HOME}/.local/bin/grub-theme-manager"
rm -f "${HOME}/.local/share/applications/grub-theme-manager.desktop"
rm -rf "${HOME}/.local/share/grub-themes"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
fi

echo "==> Startup & GRUB Theme Manager successfully uninstalled."
