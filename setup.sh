#!/usr/bin/env bash
# One-Click Setup & Restore Script for Hisense Android TV (hengshan)
#
# Use this script for:
#   1. Initial setup after a TV Factory Reset or initial unboxing.
#   2. Re-applying debloat and restoring your custom launcher after a system OTA update.
#
# Automates:
#   - Bloatware and telemetry disabling via debloat-list.txt
#   - Network-wide ad-blocking with AdGuard Private DNS
#   - Installing the pre-configured custom Apple TV 4K-style launcher (bin/tvhome.apk)
#   - Setting the custom launcher as the default Android TV Home
#   - Removing leftover third-party launcher plugins (e.g. Projectivy)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TV_HOST="${TV_HOST:-10.0.10.25}"
TV_PORT="${TV_PORT:-5555}"
TARGET="${TV_HOST}:${TV_PORT}"

echo "========================================================"
echo "Hisense Android TV Debloat & Custom Launcher Setup"
echo "Target: $TARGET"
echo "========================================================"

# Check for adb
if ! command -v adb >/dev/null 2>&1; then
    echo "Error: 'adb' command not found. Please install Android platform-tools or add adb to PATH."
    exit 1
fi

echo "[1/6] Connecting to TV over ADB..."
adb connect "$TARGET"

echo "[2/6] Disabling manufacturer bloatware, telemetry & ads..."
DEBLOAT_FILE="$SCRIPT_DIR/debloat-list.txt"
if [ -f "$DEBLOAT_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        pkg="$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')"
        if [ -n "$pkg" ]; then
            adb -s "$TARGET" shell "pm disable-user --user 0 $pkg" >/dev/null 2>&1 || true
        fi
    done < "$DEBLOAT_FILE"
else
    echo "Warning: debloat-list.txt not found, skipping debloat step."
fi
echo "Bloatware disabled."

echo "[3/6] Ensuring AdGuard Private DNS is active..."
adb -s "$TARGET" shell "settings put global private_dns_specifier dns.adguard-dns.com && settings put global private_dns_mode hostname"

echo "[4/6] Installing customized CleanYourTV launcher..."
APK="$SCRIPT_DIR/bin/tvhome.apk"

if [ ! -f "$APK" ]; then
    echo "Error: Launcher APK not found at $APK"
    echo "Please build the APK using apply_to_cleanyourtv.sh or place tvhome.apk in bin/"
    exit 1
fi

adb -s "$TARGET" push "$APK" /data/local/tmp/tvhome.apk >/dev/null 2>&1
adb -s "$TARGET" shell "pm install -r /data/local/tmp/tvhome.apk; rm -f /data/local/tmp/tvhome.apk" >/dev/null 2>&1
adb -s "$TARGET" shell "pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION" >/dev/null 2>&1 || true
echo "Launcher installed successfully."

echo "[5/6] Setting CleanYourTV as default Home launcher..."
adb -s "$TARGET" shell "pm disable-user --user 0 com.google.android.apps.tv.launcherx" >/dev/null 2>&1 || true
adb -s "$TARGET" shell "pm disable-user --user 0 com.google.android.tungsten.setupwraith" >/dev/null 2>&1 || true
adb -s "$TARGET" shell "cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity" >/dev/null 2>&1 || true

echo "[6/6] Cleaning up unwanted third-party launchers & plugins..."
PROJECTIVY_PACKAGES=(
    "com.spocky.projengmenu"
    "dev.projectivy.blueprint.app"
    "com.danielkorgel.projectivy.plugin.cinemaglow"
    "tv.projectivy.plugin.wallpaperprovider.overflight"
)
for pkg in "${PROJECTIVY_PACKAGES[@]}"; do
    adb -s "$TARGET" shell "pm uninstall $pkg" >/dev/null 2>&1 || true
done

echo "Starting CleanYourTV Home..."
adb -s "$TARGET" shell "am force-stop com.gathin.tvhome && am start -n com.gathin.tvhome/.MainActivity" >/dev/null 2>&1

echo "========================================================"
echo "Success! Custom setup successfully applied."
echo "Remember to turn OFF USB debugging on your TV for security!"
echo "========================================================"
