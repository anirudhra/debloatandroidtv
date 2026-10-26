#!/usr/bin/env bash
# apply_to_cleanyourtv.sh
# Applies custom launcher modifications to an upstream CleanYourTV clone
# (https://github.com/Gathin23/cleanyourtv) and optionally builds the release APK.
#
# Usage:
#   ./apply_to_cleanyourtv.sh [path_to_cleanyourtv] [--build]
#
# Examples:
#   ./apply_to_cleanyourtv.sh ../cleanyourtv
#   ./apply_to_cleanyourtv.sh --build
#   ./apply_to_cleanyourtv.sh ../cleanyourtv --build
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CUSTOM_DIR="$SCRIPT_DIR/customizations"
TARGET_DIR="../cleanyourtv"
BUILD_APK=false

for arg in "$@"; do
    if [ "$arg" == "--build" ]; then
        BUILD_APK=true
    elif [ -n "$arg" ] && [[ "$arg" != -* ]]; then
        TARGET_DIR="$arg"
    fi
done

if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory '$TARGET_DIR' not found."
    echo "Cloning upstream CleanYourTV into '$TARGET_DIR'..."
    git clone https://github.com/Gathin23/cleanyourtv.git "$TARGET_DIR"
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# Load pinned upstream commit record from UPSTREAM_COMMIT
if [ -f "$SCRIPT_DIR/UPSTREAM_COMMIT" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/UPSTREAM_COMMIT"
fi
UPSTREAM_BASE_COMMIT="${UPSTREAM_BASE_COMMIT:-30626a8e}"
if [ -d "$TARGET_DIR/.git" ] && [ -n "$UPSTREAM_BASE_COMMIT" ]; then
    echo "Checking out pinned upstream base commit ($UPSTREAM_BASE_COMMIT)..."
    git -C "$TARGET_DIR" checkout "$UPSTREAM_BASE_COMMIT" >/dev/null 2>&1 || true
fi

echo "Applying customizations to '$TARGET_DIR'..."

# Ensure target directories exist
mkdir -p "$TARGET_DIR/launcher/app/src/main/res/drawable"
mkdir -p "$TARGET_DIR/launcher/app/src/main/res/layout"
mkdir -p "$TARGET_DIR/launcher/app/src/main/res/values"
mkdir -p "$TARGET_DIR/launcher/app/src/main/res/xml"
mkdir -p "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome"

# Copy custom assets and source files
cp "$CUSTOM_DIR/banner_youtube.png" "$TARGET_DIR/launcher/app/src/main/res/drawable/"
cp "$CUSTOM_DIR/ic_wifi_off.xml" "$TARGET_DIR/launcher/app/src/main/res/drawable/"
cp "$CUSTOM_DIR/MainActivity.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/Config.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/HomeKeyService.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/AppAdapter.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/AppLaunchActivity.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/RemoteKeys.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/ServiceRepair.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/Sleep.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/SleepService.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/Weather.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/activity_main.xml" "$TARGET_DIR/launcher/app/src/main/res/layout/"
cp "$CUSTOM_DIR/config.xml" "$TARGET_DIR/launcher/app/src/main/res/values/"
cp "$CUSTOM_DIR/strings.xml" "$TARGET_DIR/launcher/app/src/main/res/values/"
cp "$CUSTOM_DIR/bools.xml" "$TARGET_DIR/launcher/app/src/main/res/values/"
cp "$CUSTOM_DIR/sleep_service.xml" "$TARGET_DIR/launcher/app/src/main/res/xml/"
cp "$CUSTOM_DIR/AndroidManifest.xml" "$TARGET_DIR/launcher/app/src/main/"

echo "Successfully merged customized files into $TARGET_DIR/launcher."

if [ "$BUILD_APK" = true ]; then
    echo "Building release APK..."
    # Auto-detect JDK 17 and Android SDK if not already set in environment
    if [ -z "${JAVA_HOME:-}" ]; then
        for jdir in "$TARGET_DIR/tools/jdk-17" "/usr/lib/jvm/java-17-openjdk-amd64" "/usr/lib/jvm/java-17-openjdk" "/opt/homebrew/opt/openjdk@17"; do
            if [ -d "$jdir" ]; then
                export JAVA_HOME="$jdir"
                export PATH="$JAVA_HOME/bin:$PATH"
                break
            fi
        done
    fi
    if [ -z "${ANDROID_HOME:-}" ]; then
        for sdir in "$TARGET_DIR/tools/android-sdk" "$HOME/Android/Sdk" "$HOME/Library/Android/sdk"; do
            if [ -d "$sdir" ]; then
                export ANDROID_HOME="$sdir"
                break
            fi
        done
    fi

    (
        cd "$TARGET_DIR/launcher"
        ./gradlew assembleRelease --console=plain
    )
    mkdir -p "$SCRIPT_DIR/bin"
    cp "$TARGET_DIR/launcher/app/build/outputs/apk/release/app-release.apk" "$SCRIPT_DIR/bin/tvhome.apk"
    echo "New APK built and saved to bin/tvhome.apk!"
fi

echo "Done."
