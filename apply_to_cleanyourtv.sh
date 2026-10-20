#!/usr/bin/env bash
# apply_to_cleanyourtv.sh
# Applies custom launcher modifications to an upstream CleanYourTV clone
# (https://github.com/Gathin23/cleanyourtv) and optionally builds the release APK.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CUSTOM_DIR="$SCRIPT_DIR/customizations"
TARGET_DIR="${1:-../cleanyourtv}"
BUILD_APK=false

for arg in "$@"; do
    if [ "$arg" == "--build" ]; then
        BUILD_APK=true
    fi
done

if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory '$TARGET_DIR' not found."
    echo "Cloning upstream CleanYourTV into '$TARGET_DIR'..."
    git clone https://github.com/Gathin23/cleanyourtv.git "$TARGET_DIR"
fi

echo "Applying customizations to '$TARGET_DIR'..."

# Copy custom assets and source files
cp "$CUSTOM_DIR/banner_youtube.png" "$TARGET_DIR/launcher/app/src/main/res/drawable/"
cp "$CUSTOM_DIR/ic_wifi_off.xml" "$TARGET_DIR/launcher/app/src/main/res/drawable/"
cp "$CUSTOM_DIR/MainActivity.java" "$TARGET_DIR/launcher/app/src/main/java/com/gathin/tvhome/"
cp "$CUSTOM_DIR/activity_main.xml" "$TARGET_DIR/launcher/app/src/main/res/layout/"
cp "$CUSTOM_DIR/config.xml" "$TARGET_DIR/launcher/app/src/main/res/values/"
cp "$CUSTOM_DIR/strings.xml" "$TARGET_DIR/launcher/app/src/main/res/values/"
cp "$CUSTOM_DIR/bools.xml" "$TARGET_DIR/launcher/app/src/main/res/values/"

echo "Successfully copied customized files into $TARGET_DIR/launcher."

if [ "$BUILD_APK" = true ]; then
    echo "Building release APK..."
    (
        cd "$TARGET_DIR/launcher"
        ./gradlew assembleRelease --console=plain
    )
    mkdir -p "$SCRIPT_DIR/bin"
    cp "$TARGET_DIR/launcher/app/build/outputs/apk/release/app-release.apk" "$SCRIPT_DIR/bin/tvhome.apk"
    echo "New APK built and saved to bin/tvhome.apk!"
fi

echo "Done."
