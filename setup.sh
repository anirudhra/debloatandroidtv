#!/usr/bin/env bash
# One-Click Setup & Restore Script for Android TV
#
# Supports multiple TV brand profiles (e.g. hisense_u7, tcl).
#
# Usage:
#   ./setup.sh [profile] [tv_ip]
#
# Examples:
#   ./setup.sh hisense_u7 10.0.10.25
#   ./setup.sh tcl 10.0.10.26
#   ./setup.sh hisense_u7
#   TV_HOST=10.0.10.25 DEVICE=hisense_u7 ./setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEVICES_DIR="$SCRIPT_DIR/devices"

# -----------------------------------------------------------------------------
# Parse Arguments & Defaults
# -----------------------------------------------------------------------------
PARAM1="${1:-}"
PARAM2="${2:-}"

PROFILE="${DEVICE:-}"
TV_HOST="${TV_HOST:-10.0.10.25}"
TV_PORT="${TV_PORT:-5555}"

# Helper to check if a string looks like an IP or hostname
is_ip() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$1" =~ : ]]
}

if [ -n "$PARAM1" ]; then
    if is_ip "$PARAM1"; then
        TV_HOST="$PARAM1"
    else
        PROFILE="$PARAM1"
    fi
fi

if [ -n "$PARAM2" ]; then
    if is_ip "$PARAM2"; then
        TV_HOST="$PARAM2"
    else
        PROFILE="$PARAM2"
    fi
fi

TARGET="${TV_HOST}:${TV_PORT}"

echo "========================================================"
echo "Android TV Debloat & Custom Launcher Setup"
echo "Target Device: $TARGET"
echo "========================================================"

# Check for adb
if ! command -v adb >/dev/null 2>&1; then
    echo "Error: 'adb' command not found. Please install Android platform-tools or add adb to PATH."
    exit 1
fi

echo "[1/6] Connecting to TV over ADB ($TARGET)..."
adb connect "$TARGET"

# -----------------------------------------------------------------------------
# Profile Detection / Selection
# -----------------------------------------------------------------------------
AVAILABLE_PROFILES=()
if [ -d "$DEVICES_DIR" ]; then
    for d in "$DEVICES_DIR"/*; do
        if [ -d "$d" ]; then
            AVAILABLE_PROFILES+=("$(basename "$d")")
        fi
    done
fi

if [ -z "$PROFILE" ]; then
    # Try auto-detecting brand from TV over ADB
    BRAND="$(adb -s "$TARGET" shell getprop ro.product.brand 2>/dev/null | tr -d '\r\n[:space:]' | tr '[:upper:]' '[:lower:]' || true)"
    
    if [[ "$BRAND" == *"hisense"* ]] && [ -d "$DEVICES_DIR/hisense_u7" ]; then
        PROFILE="hisense_u7"
        echo "Auto-detected Hisense TV. Selected profile: $PROFILE"
    elif [[ "$BRAND" == *"tcl"* ]] && [ -d "$DEVICES_DIR/tcl" ]; then
        PROFILE="tcl"
        echo "Auto-detected TCL TV. Selected profile: $PROFILE"
    elif [ -t 0 ] && [ "${#AVAILABLE_PROFILES[@]}" -gt 0 ]; then
        echo ""
        echo "Select TV Brand Profile:"
        select opt in "${AVAILABLE_PROFILES[@]}"; do
            if [ -n "$opt" ]; then
                PROFILE="$opt"
                break
            fi
        done
    else
        PROFILE="hisense_u7"
        echo "Defaulting to profile: $PROFILE"
    fi
fi

echo "Using profile: $PROFILE"

# Locate debloat list
DEBLOAT_FILE=""
if [ -f "$DEVICES_DIR/$PROFILE/debloat-list.txt" ]; then
    DEBLOAT_FILE="$DEVICES_DIR/$PROFILE/debloat-list.txt"
elif [ -f "$SCRIPT_DIR/$PROFILE/debloat-list.txt" ]; then
    DEBLOAT_FILE="$SCRIPT_DIR/$PROFILE/debloat-list.txt"
elif [ -f "$SCRIPT_DIR/debloat-list.txt" ]; then
    DEBLOAT_FILE="$SCRIPT_DIR/debloat-list.txt"
fi

# -----------------------------------------------------------------------------
# Debloat Execution
# -----------------------------------------------------------------------------
echo "[2/6] Disabling manufacturer bloatware, telemetry & ads..."
if [ -n "$DEBLOAT_FILE" ] && [ -f "$DEBLOAT_FILE" ]; then
    echo "Applying debloat packages from: $DEBLOAT_FILE"
    COUNT=0
    while IFS= read -r line || [ -n "$line" ]; do
        pkg="$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')"
        if [ -n "$pkg" ]; then
            adb -s "$TARGET" shell "pm disable-user --user 0 $pkg" >/dev/null 2>&1 || true
            COUNT=$((COUNT + 1))
        fi
    done < "$DEBLOAT_FILE"
    echo "Processed $COUNT debloat packages."
else
    echo "Warning: No debloat-list.txt found for profile '$PROFILE'. Skipping package debloat."
fi

# -----------------------------------------------------------------------------
# AdGuard Private DNS
# -----------------------------------------------------------------------------
echo "[3/6] Ensuring AdGuard Private DNS is active..."
adb -s "$TARGET" shell "settings put global private_dns_specifier dns.adguard-dns.com && settings put global private_dns_mode hostname"

# -----------------------------------------------------------------------------
# Install Custom Launcher
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Configure Default Home
# -----------------------------------------------------------------------------
echo "[5/6] Setting CleanYourTV as default Home launcher..."
adb -s "$TARGET" shell "pm disable-user --user 0 com.google.android.apps.tv.launcherx" >/dev/null 2>&1 || true
adb -s "$TARGET" shell "pm disable-user --user 0 com.google.android.tungsten.setupwraith" >/dev/null 2>&1 || true
adb -s "$TARGET" shell "cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity" >/dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# Clean up Third-Party Helpers
# -----------------------------------------------------------------------------
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
