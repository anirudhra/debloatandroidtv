#!/usr/bin/env bash
# CleanYourTV - One-Click Setup & Restore Script for Hisense hengshan
#
# Use this script for:
#   1. Initial setup after a TV Factory Reset or initial unboxing.
#   2. Re-applying your setup after a system OTA firmware update.
#
# Everything is automated: debloat, AdGuard Private DNS, custom launcher install,
# and default Home configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TV_HOST="${TV_HOST:-10.0.10.25}"
TV_PORT="${TV_PORT:-5555}"
TARGET="${TV_HOST}:${TV_PORT}"

echo "========================================================"
echo "CleanYourTV: Applying Custom Setup on $TARGET"
echo "========================================================"

echo "[1/6] Connecting to TV over ADB..."
adb connect "$TARGET"

echo "[2/6] Disabling manufacturer bloatware, telemetry & ads..."
DEBLOAT_PACKAGES=(
    "com.vt.tv.evservice"
    "com.vt.hishow"
    "com.vt.alexa"
    "com.vt.storemode"
    "com.vt.tv.b2b"
    "com.vt.factory"
    "com.vt.fte"
    "com.vt.tv.protector"
    "com.vt.tv.calmanconnector"
    "tv.mopa.ginga"
    "com.vt.tv.interactive"
    "com.vt.tv.mobiledeviceconnectiontips"
    "android.autoinstalls.config.google.gtvpai"
    "com.google.android.partnersetup"
    "com.google.android.feedback"
    "com.android.printspooler"
    "com.google.android.syncadapters.calendar"
    "com.android.providers.calendar"
    "com.android.providers.contacts"
)

for pkg in "${DEBLOAT_PACKAGES[@]}"; do
    adb -s "$TARGET" shell "pm disable-user --user 0 $pkg" >/dev/null 2>&1 || true
done
echo "Bloatware disabled."

echo "[3/6] Ensuring AdGuard Private DNS is active..."
adb -s "$TARGET" shell "settings put global private_dns_specifier dns.adguard-dns.com && settings put global private_dns_mode hostname"

echo "[4/6] Installing customized CleanYourTV launcher..."
APK="$SCRIPT_DIR/bin/tvhome.apk"
if [ ! -f "$APK" ]; then
    APK="$SCRIPT_DIR/launcher/app/build/outputs/apk/release/app-release.apk"
fi

# Auto-build if APK is not already compiled
if [ ! -f "$APK" ]; then
    echo "Release APK not found. Building from source..."
    export JAVA_HOME="${JAVA_HOME:-$SCRIPT_DIR/tools/jdk-17}"
    export ANDROID_HOME="${ANDROID_HOME:-$SCRIPT_DIR/tools/android-sdk}"
    export PATH="$JAVA_HOME/bin:$PATH"
    (cd "$SCRIPT_DIR/launcher" && ./gradlew assembleRelease --console=plain)
    APK="$SCRIPT_DIR/launcher/app/build/outputs/apk/release/app-release.apk"
fi

adb -s "$TARGET" push "$APK" /data/local/tmp/tvhome.apk >/dev/null 2>&1
adb -s "$TARGET" shell "pm install -r /data/local/tmp/tvhome.apk; rm -f /data/local/tmp/tvhome.apk" >/dev/null 2>&1
adb -s "$TARGET" shell "pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION" >/dev/null 2>&1 || true
echo "Launcher installed."

echo "[5/6] Setting CleanYourTV as default Home..."
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
echo "Success! Custom CleanYourTV setup applied."
echo "========================================================"
