# Multi-Device Android TV Debloat & Custom Launcher Framework

A modular, lightweight debloat configuration and setup framework for Android TV / Google TV.

This repository stores personal customizations, device debloat package lists, automation scripts, and pre-built binaries. It replaces the stock ad-laden Google TV interface with a clean, responsive Apple TV 4K-style native launcher based on [CleanYourTV](https://github.com/Gathin23/cleanyourtv).

Designed to support multiple TV brand models and series (e.g., **Hisense U7N**, **TCL TVs**) by supplying the path to any target debloat list.

---

## Repository Structure

```text
debloatandroidtv/
├── README.md               # Complete setup, build, and deployment guide
├── .gitignore              # Automatically excludes device backups & build artifacts
├── LICENSE                 # MIT License
├── setup.sh                # Multi-device ADB setup, discovery & verification script
├── apply_to_cleanyourtv.sh # Merges customizations into upstream CleanYourTV clone
├── bin/
│   └── tvhome.apk          # Pre-compiled customized launcher APK (ready to deploy)
├── customizations/         # Unified launcher customizations & assets
│   ├── launcher.patch      # Full binary git patch against upstream CleanYourTV
│   ├── MainActivity.java   # Ambient glow, Control Center, Hotplug & Pixel Drift logic
│   ├── AppAdapter.java     # Move mode (hold OK to reorder, App Info, Reset order)
│   ├── Sleep.java          # Sleep timer cycle (30/60/90m) & standby executor
│   ├── SleepService.java   # Standby accessibility service (GLOBAL_ACTION_LOCK_SCREEN)
│   ├── Weather.java        # Open-Meteo live weather client with WMO emoji mapper
│   ├── activity_main.xml   # Weather layout, HDMI alert banner & status bar
│   ├── sleep_service.xml   # Accessibility service configuration
│   ├── AndroidManifest.xml # Permissions (Internet, Kill processes) & service declarations
│   ├── config.xml          # Tube rename, YouTube banner, 4 dock apps, weather config
│   ├── strings.xml         # 2-row date format, Control Center & move mode strings
│   ├── bools.xml           # Multi-line date enabled
│   ├── banner_youtube.png  # High-res YouTube leanback banner for Tube
│   └── ic_wifi_off.xml     # Offline status icon for Wi-Fi pill
└── tv/                     # Brand & model debloat package lists
    ├── hisense/
    │   └── u7n.txt         # Hisense U7N debloat & background lockdown list
    └── tcl/
        └── model.txt       # TCL debloat list (Samba TV ACR, logkit, promo packages)
```

---

## Custom Launcher Features (`bin/tvhome.apk`)

* **App Reordering / Move Mode:** Hold OK on any app tile to open options:
  * **Move app:** Use D-pad to move the tile anywhere across dock and grid, press OK to drop. Custom order is saved locally and persists across reboots.
  * **App info:** Direct access to Android system application settings.
  * **Reset app order:** Reverts ordering back to the default configuration.
* **Apple TV-Style Control Center:** Hold OK on the **Settings** pill to open a sleek glass overlay:
  * **Sleep timer:** Cycle through 30 / 60 / 90 min with live remaining countdown.
  * **Turn off now:** Puts the TV into instant standby via `SleepService` accessibility integration.
  * **Free up memory:** One-click RAM cleaner that stops background cached apps and displays freed memory.
  * **Sound output:** Live audio output status (Soundbar via HDMI ARC vs TV speakers) with quick jump to Sound settings.
  * **Screensaver:** Immediately launches the active system screensaver (`Somnambulator`).
  * **Launcher Settings & Dock Edit:** Quick access to launcher customization.
* **Live Weather next to Clock:** Clean temperature and condition emoji (☀️, ⛅, 🌧️, ❄️) next to the date, powered by Open-Meteo (free, no API keys, private, cached locally every 30m).
* **HDMI Hotplug Auto-Detection:** Instant banner notification when an HDMI device is connected or powered on (*"HDMI 2 connected · Press OK to switch"*). Press OK to switch immediately, or Back to dismiss (auto-dismisses after 8s).
* **OLED / Mini-LED Pixel Drift:** Microscopic 1.5dp subpixel drift every minute across static clock and status elements to prevent static image retention and burn-in on premium OLED and Mini-LED panels.
* **Full-Grid Dynamic Ambient Glow:** Samples dominant colors from every app's artwork and casts a smooth ambient glow as you scroll through the entire grid, not just the dock row.
* **Custom App Branding:** TizenTube is prominently titled **Tube** and uses the official YouTube Leanback icon (persists across TizenTube updates).
* **Pinned Dock:** Dedicated bottom dock containing Tube, Apple TV, Amazon Prime Video, and LocalNow.
* **Refined Status Bar:**
  * Clean thin clock (Outfit font) with greeting text removed.
  * Date formatted cleanly into 2 rows (Row 1: Day of week, Row 2: Date & Month).
  * Status pills: `Inputs` (with icon and text), `Wi-Fi` (icon-only circular pill with offline detection), and `Settings` (icon-only circular pill).

---

## Command Reference (`./setup.sh --help`)

You can view the full command reference and examples directly from your terminal anytime:

```bash
./setup.sh --help
```

| Command / Syntax | Purpose |
|---|---|
| `./setup.sh <list_path> [tv_ip]` | **Apply Setup:** Debloats TV, configures AdGuard DNS, installs custom launcher, and runs verification. |
| `./setup.sh discover [tv_ip] [output_file]` | **Audit TV:** Scans installed packages on a TV and generates a categorized debloat candidate list. |
| `./setup.sh verify [tv_ip]` | **Health Check:** Verifies Home launcher, DNS ad-blocking, AppOps starvation, and system RAM. |
| `./setup.sh` | **Interactive Menu:** Scans `./tv/` for debloat lists and presents an interactive menu. |
| `./setup.sh --help` / `-h` | Displays the built-in command reference and examples. |

---

## Workflow 1: Quick Deploy to TV (Using Pre-built APK)

*No Java or Android SDK required!*

### Step 1: Enable USB Debugging on Your TV
1. On your TV, navigate to **Settings** → **Device Preferences** (or **System**) → **About**.
2. Scroll to **Build** / **Android TV OS build** and press **OK** on your remote **7 times** until you see *"You are now a developer!"*
3. Go back one menu to **Developer options**, and turn **USB debugging** to **ON**.
4. Check your TV's IP address under **Settings** → **Network & Internet**.

### Step 2: Run Setup
Run `setup.sh` from your computer, passing the path to the target debloat list and your TV's IP:

```bash
# For Hisense U7N:
./setup.sh tv/hisense/u7n.txt 10.0.10.25

# For TCL TV:
./setup.sh tv/tcl/model.txt 10.0.10.26
```

*(Arguments can be supplied in any order. The script automatically takes a pre-flight snapshot in `backup/`, applies the debloat & background lockdowns, configures AdGuard DNS, installs the custom launcher, grants coarse/fine location for weather, automatically activates `SleepService` for instant standby and the sleep timer, and runs health verification).*

### Step 3: Secure Your TV
Once the script finishes:
1. Go back to **Developer options** on your TV.
2. Turn **USB debugging** back to **OFF**.
3. Reboot the TV. (This closes port 5555 and ensures your TV is completely secure).

> [!NOTE]
> **After System OTA Updates or Factory Reset:**  
> If an OTA firmware update resets your home screen or re-enables factory bloatware, simply re-enable USB debugging and run `./setup.sh tv/hisense/u7n.txt <ip>` again. Everything will be restored in seconds.

---

## Workflow 2: Automatic TV Package Discovery (`discover`)

When setting up a new TV (like your upcoming TCL TVs), you don't need to guess package names. Use the built-in auditor:

```bash
./setup.sh discover 10.0.10.26 tv/tcl/c645.txt
```

* **What it does:**
  1. Inspects the connected TV's hardware model, brand, and Android version.
  2. Scans all installed packages while **strictly protecting** critical OS and hardware framework components (TV inputs, tuner, HDMI, remote pairing).
  3. Uses pattern matching (`ads`, `analytics`, `telemetry`, `storemode`, `alexa`, `promos`) to group candidates into clean categories.
  4. Generates a commented, ready-to-use template file at the specified path.

---

## Workflow 3: Health Check & Verification (`verify`)

To verify whether a TV's debloat, custom launcher, and ad-blocking DNS are working at any time:

```bash
./setup.sh verify 10.0.10.25
```

* **What it tests:**
  * **Default Home Launcher:** Confirms `com.gathin.tvhome` is the active Priority 0 Home.
  * **AdGuard Private DNS:** Validates `private_dns_mode` and verifies ad-domain blocking.
  * **Disabled Packages:** Reports the total count of disabled bloatware.
  * **Background Starvation:** Confirms AppOps background execution denial for protected telemetry services.
  * **System Memory:** Reports current free RAM and system status.

---

## Advanced Feature: Background Lockdown (`lockdown:`)

Certain OEM services trigger Android System Recovery if disabled using `pm disable-user` (e.g. `com.vt.tv.smartsense` and `com.vt.tv.aiot` on Hisense MediaTek firmware).

To silence these services safely without bricking or triggering recovery, prefix them with `lockdown:` in your debloat list:

```text
# --- Background Lockdown (Starve Background CPU, Do Not Disable) ---
lockdown:com.vt.tv.smartsense
lockdown:com.vt.tv.smartsense.ui
lockdown:com.vt.tv.aiot
lockdown:com.vt.tv.ai_sense
```

`setup.sh` automatically uses Android AppOps policies (`RUN_ANY_IN_BACKGROUND ignore` and `RUN_IN_BACKGROUND ignore`) to deny background CPU cycles and stop the services from running, keeping your system 100% stable.

---

## Workflow 4: Clone Upstream, Merge Customizations, Build & Deploy

If you want to pull updates from upstream [CleanYourTV](https://github.com/Gathin23/cleanyourtv), recompile the launcher, or make further modifications, you have two flexible methods:

### Option A: Automated Build Script (Recommended)

Run one command from the `debloatandroidtv` root:

```bash
cd ~/code/github/debloatandroidtv
./apply_to_cleanyourtv.sh ../cleanyourtv --build
```

* **What it does automatically:**
  1. Checks if `../cleanyourtv` exists. If not, it clones `https://github.com/Gathin23/cleanyourtv.git` for you.
  2. Merges all custom assets, Java classes (`MainActivity.java`, `AppAdapter.java`, `Sleep.java`, `SleepService.java`, `Weather.java`), layout files, strings, and manifests into the clone.
  3. Uses `./gradlew assembleRelease` to compile the optimized APK.
  4. Automatically copies the compiled release APK into `bin/tvhome.apk`.

### Option B: Native Git Patch Workflow

If you prefer standard Git patching:

```bash
# 1. Clone upstream CleanYourTV
cd ~/code/github
git clone https://github.com/Gathin23/cleanyourtv.git
cd cleanyourtv

# 2. Apply the binary git patch from this repo
git apply ~/code/github/debloatandroidtv/customizations/launcher.patch

# 3. Build release APK
cd launcher
./gradlew assembleRelease

# 4. Copy binary back to debloat kit
cp app/build/outputs/apk/release/app-release.apk ~/code/github/debloatandroidtv/bin/tvhome.apk
```

### Deploy to Your TV
Once built, simply run:
```bash
./setup.sh tv/hisense/u7n.txt 10.0.10.25
```

---

## Security & Privacy Notice

* The `.gitignore` ensures all device backups (`backup/`), dumps, logs, and private keys remain local and are never committed to GitHub.
* No packages are permanently removed from the TV; everything is disabled via `pm disable-user --user 0` and can be re-enabled if needed.
* Always turn OFF USB debugging on the TV when setup is complete.
