#!/usr/bin/env bash
# One-Click Setup & Restore Script for Android TV
#
# Applies debloat package lists, sets AdGuard Private DNS, installs
# the customized Apple TV 4K-style launcher, and sets it as default Home.
#
# Usage:
#   ./setup.sh <debloat_list_path> [tv_ip]
#
# Examples:
#   ./setup.sh tv/hisense/u7n.txt 10.0.10.25
#   ./setup.sh tv/tcl/model.txt 10.0.10.26
#   ./setup.sh tv/hisense/u7n.txt
#   DEBLOAT_LIST=tv/hisense/u7n.txt TV_HOST=10.0.10.25 ./setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TV_DIR="$SCRIPT_DIR/tv"

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------
PARAM1="${1:-}"
PARAM2="${2:-}"

DEBLOAT_LIST="${DEBLOAT_LIST:-}"
TV_HOST="${TV_HOST:-10.0.10.25}"
TV_PORT="${TV_PORT:-5555}"

# Helper to check if a parameter looks like an IP or hostname
is_ip() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$1" =~ : ]]
}

# Helper to check if a parameter looks like a file path
is_file_path() {
    [[ "$1" == *.txt ]] || [ -f "$1" ] || [ -f "$SCRIPT_DIR/$1" ]
}

for p in "$PARAM1" "$PARAM2"; do
    if [ -n "$p" ]; then
        if is_ip "$p"; then
            TV_HOST="$p"
        elif is_file_path "$p"; then
            DEBLOAT_LIST="$p"
        elif [ -z "$DEBLOAT_LIST" ]; then
            DEBLOAT_LIST="$p"
        fi
    fi
done

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

# -----------------------------------------------------------------------------
# Resolve Debloat List Path
# -----------------------------------------------------------------------------
if [ -z "$DEBLOAT_LIST" ]; then
    AVAILABLE_LISTS=()
    if [ -d "$TV_DIR" ]; then
        while IFS= read -r f; do
            AVAILABLE_LISTS+=("${f#$SCRIPT_DIR/}")
        done < <(find "$TV_DIR" -type f -name "*.txt" | sort)
    fi

    if [ -t 0 ] && [ "${#AVAILABLE_LISTS[@]}" -gt 1 ]; then
        echo "Select a debloat list to apply:"
        select opt in "${AVAILABLE_LISTS[@]}"; do
            if [ -n "$opt" ]; then
                DEBLOAT_LIST="$opt"
                break
            fi
        done
    elif [ "${#AVAILABLE_LISTS[@]}" -ge 1 ]; then
        DEBLOAT_LIST="${AVAILABLE_LISTS[0]}"
        echo "Auto-selected debloat list: $DEBLOAT_LIST"
    else
        DEBLOAT_LIST="tv/hisense/u7n.txt"
    fi
fi

# Resolve relative path if needed
if [ ! -f "$DEBLOAT_LIST" ] && [ -f "$SCRIPT_DIR/$DEBLOAT_LIST" ]; then
    DEBLOAT_LIST="$SCRIPT_DIR/$DEBLOAT_LIST"
fi

if [ ! -f "$DEBLOAT_LIST" ]; then
    echo "Error: Debloat list not found at '$DEBLOAT_LIST'"
    if [ -d "$TV_DIR" ]; then
        echo "Available lists in ./tv/:"
        find "$TV_DIR" -type f -name "*.txt" | sed "s|$SCRIPT_DIR/|  - |"
    fi
    exit 1
fi

echo "Using debloat list: $DEBLOAT_LIST"

# -----------------------------------------------------------------------------
# Connect over ADB
# -----------------------------------------------------------------------------
echo "[1/6] Connecting to TV over ADB ($TARGET)..."
adb connect "$TARGET"

# -----------------------------------------------------------------------------
# Debloat Execution
# -----------------------------------------------------------------------------
echo "[2/6] Disabling bloatware, telemetry & ads from $DEBLOAT_LIST..."
COUNT=0
while IFS= read -r line || [ -n "$line" ]; do
    pkg="$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')"
    if [ -n "$pkg" ]; then
        adb -s "$TARGET" shell "pm disable-user --user 0 $pkg" >/dev/null 2>&1 || true
        COUNT=$((COUNT + 1))
    fi
done < "$DEBLOAT_LIST"
echo "Processed $COUNT debloat packages."

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
