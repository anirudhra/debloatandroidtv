# CleanYourTV — Hisense Android TV Edition

A lightweight, bloat-free Android TV setup that replaces the ad-laden stock Google TV interface with a clean, responsive Apple TV 4K-style native launcher.

Optimized and tested for **Hisense Android TV (hengshan / SmartTV 4K FFM)** running Android 12.

---

## What This Setup Does

1. **Strips Bloatware & Telemetry:**
   * Disables Hisense ACR (Automatic Content Recognition telemetry), promo screensavers, and Alexa.
   * Disables store/demo modes, factory tools, and aggressive background cleaners (`DeviceAssistant`).
   * Disables Google partner auto-installers (`gtvpai`) and tracking services.
   * Uninstalls third-party launcher helpers/plugins (e.g., Projectivy).
2. **Preserves Critical Hardware & Streaming Services:**
   * Live TV tuner and HDMI inputs are 100% functional via the TV input framework.
   * Remote control pairing, audio services, and on-screen keyboard remain intact.
   * Chromecast built-in, DLNA, and Apple AirPlay are preserved.
   * System OTA firmware update services remain enabled.
   * All user-installed streaming apps (Netflix, Prime Video, Apple TV, Plex, SmartTube, Steam Link, etc.) remain untouched.
3. **Ad-Blocking Private DNS:**
   * Pre-configured with AdGuard Private DNS (`dns.adguard-dns.com`) for network-wide ad blocking (excluding YouTube video ads).
4. **Custom Apple TV 4K-Style Native Launcher:**
   * Ultra-lightweight native Android TV launcher (under 405 KB).
   * **Full-Grid Dynamic Ambient Glow:** Samples the dominant colors from every app's artwork and casts a smooth ambient glow as you scroll through the entire grid, not just the dock.
   * **Custom Dock App Pinning:** Dedicated bottom dock inside a rounded band with quick access to your top apps.
   * **Custom App Branding:** TizenTube is prominently titled **Tube** and uses the official YouTube Leanback icon (persists across TizenTube updates).
   * **Refined Status Bar:**
     * Clean thin clock (Outfit font) with greeting text removed.
     * Date cleanly formatted into 2 rows (Row 1: Day of week, Row 2: Date & Month).
     * Frosted pills: `Inputs` (with icon and text), `Wi-Fi` (icon-only circular pill with offline detection), and `Settings` (icon-only circular pill).

---

## Security & Privacy Notice for Public Repositories

> [!NOTE]
> **Is it safe to publish this repository publicly?**  
> **Yes.** The `.gitignore` in this repository automatically excludes the `backup/` directory, which contains device-specific dumps (serial numbers, MAC addresses, Android ID, and screen captures).  
> The committed files contain only open-source launcher code, layouts, and public Android package names.

---

## One-Click Setup Script (`setup.sh`)

This repository includes a master setup script: [`setup.sh`](setup.sh).

### When to Use This Script:
1. **Initial Setup / After Factory Reset:**  
   If you ever factory reset the TV or set up a new Hisense TV of the same model, running `./setup.sh` performs the entire debloat, enables AdGuard Private DNS, installs the customized launcher, and configures it as default Home in one go.
2. **After System OTA Firmware Updates:**  
   Manufacturer firmware updates can re-enable stock bloatware or reset the launcher back to stock Google TV. Running `./setup.sh` immediately restores your clean setup in seconds with all your customizations intact.

### How to Run:
1. On the TV, enable **USB debugging** under **Developer options** (*Settings → Device Preferences → About → press OK on Build 7 times → back → Developer options*).
2. Connect your TV to Wi-Fi.
3. Run from your computer:
   ```bash
   TV_HOST=<your-tv-ip> ./setup.sh
   ```
   *(If omitted, `TV_HOST` defaults to `10.0.10.25`)*
4. Once completed, turn **USB debugging** back to **OFF** on the TV and reboot to keep your TV secure.

---

## Rebuilding the Launcher from Source

To build and sideload the launcher from source:

```bash
# Set up JDK 17 and Android SDK paths
export JAVA_HOME="$(pwd)/tools/jdk-17"
export ANDROID_HOME="$(pwd)/tools/android-sdk"
export PATH="$JAVA_HOME/bin:$PATH"

# Build release APK
cd launcher
./gradlew assembleRelease

# Push and install over ADB
adb push app/build/outputs/apk/release/app-release.apk /data/local/tmp/tvhome.apk
adb shell "pm install -r /data/local/tmp/tvhome.apk; rm -f /data/local/tmp/tvhome.apk"
adb shell "am force-stop com.gathin.tvhome && am start -n com.gathin.tvhome/.MainActivity"
```

---

## Credits & Upstream

Forked and customized from [CleanYourTV](https://github.com/Gathin23/cleanyourtv). See `README.upstream.md` for full project history and multi-brand device catalogs.
