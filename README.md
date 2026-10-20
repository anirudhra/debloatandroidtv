# Hisense Android TV Debloat & Custom Launcher Setup

A lightweight, bloat-free configuration and setup kit for **Hisense Android TV (SmartTV 4K FFM / hengshan, Android 12)**. 

This repository contains personal customization files, debloat lists, pre-built APKs, and automation scripts. It replaces the stock Google TV launcher with a clean, fast, ad-free Apple TV 4K-style native launcher based on [CleanYourTV](https://github.com/Gathin23/cleanyourtv).

---

## Repository Structure

```text
debloatandroidtv/
├── README.md               # Documentation & usage guide
├── .gitignore              # Ignores local backups & temporary files
├── LICENSE                 # MIT License
├── setup.sh                # Master one-click ADB script (debloat, DNS, launcher install)
├── debloat-list.txt        # Exact list of 19 Hisense & Google telemetry packages disabled
├── apply_to_cleanyourtv.sh # Helper to apply customizations to an upstream CleanYourTV clone
├── bin/
│   └── tvhome.apk          # Pre-compiled custom launcher APK (394 KB, ready to install)
└── customizations/         # Custom launcher source files & patch
    ├── launcher.patch      # Git diff against upstream CleanYourTV
    ├── MainActivity.java   # Full-grid ambient glow & icon-only wifi logic
    ├── activity_main.xml   # Clean status bar & icon-only pill layouts
    ├── config.xml          # Dock apps, Live TV mapping, custom labels & banners
    ├── strings.xml         # 2-row date format
    ├── bools.xml           # Multi-line date setting
    ├── banner_youtube.png  # High-res YouTube leanback banner for Tube
    └── ic_wifi_off.xml     # Offline status icon for Wi-Fi pill
```

---

## What This Setup Does

1. **Debloats Hisense & Google Telemetry:**
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
   * Configures AdGuard Private DNS (`dns.adguard-dns.com`) for network-wide ad blocking.
4. **Custom Apple TV 4K-Style Native Launcher (`bin/tvhome.apk`):**
   * **Full-Grid Dynamic Ambient Glow:** Samples the dominant colors from every app's artwork and casts a smooth ambient glow as you scroll through the entire grid, not just the dock.
   * **Custom Dock App Pinning:** Dock contains Tube, Apple TV, Prime Video, and LocalNow.
   * **Custom App Branding:** TizenTube is prominently titled **Tube** and uses the official YouTube Leanback icon (persists across TizenTube updates).
   * **Refined Status Bar:**
     * Clean thin clock (Outfit font) with greeting text removed.
     * Date cleanly formatted into 2 rows (Row 1: Day of week, Row 2: Date & Month).
     * Frosted pills: `Inputs` (with icon and text), `Wi-Fi` (icon-only circular pill with offline detection), and `Settings` (icon-only circular pill).

---

## One-Click Setup Script (`setup.sh`)

Use [`setup.sh`](setup.sh) for:
1. **Initial Setup / After Factory Reset:** Completely configures the TV out-of-the-box in seconds.
2. **After System OTA Firmware Updates:** Restores debloat state, AdGuard DNS, and custom launcher if an update re-enables stock apps.

### How to Run:
1. On your TV, enable **USB debugging** under **Developer options** (*Settings → Device Preferences → About → press OK on Build 7 times → back → Developer options*).
2. Make sure your computer is connected to the same local network as the TV.
3. Run from your computer:
   ```bash
   TV_HOST=10.0.10.25 ./setup.sh
   ```
   *(Replace `10.0.10.25` with your TV's IP address if different)*
4. Once completed, turn **USB debugging** back to **OFF** on the TV and reboot to keep your TV secure.

---

## Applying Customizations to Upstream CleanYourTV

If you want to build the launcher from upstream source instead of using the pre-compiled `bin/tvhome.apk`:

```bash
# Clone upstream or specify an existing directory
./apply_to_cleanyourtv.sh ../cleanyourtv --build
```

Or manually using the patch:
```bash
cd /path/to/cleanyourtv
git apply /path/to/debloatandroidtv/customizations/launcher.patch
```

---

## Security & Privacy Notice

The `.gitignore` in this repository automatically excludes `backup/`, ensuring local device dumps (serial numbers, MAC addresses, Android ID, and screen captures) are never committed to public repositories.

---

## Credits

Based on the [CleanYourTV](https://github.com/Gathin23/cleanyourtv) project by Gathin23.
