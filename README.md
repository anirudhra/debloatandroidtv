# Multi-Device Android TV Debloat & Custom Launcher Framework

> [!NOTE]
> **Built upon and credited to [CleanYourTV](https://github.com/Gathin23/cleanyourtv)**  
> This project is proudly powered by and built on top of the exceptional work by [Gathin23](https://github.com/Gathin23) and the [CleanYourTV](https://github.com/Gathin23/cleanyourtv) community. All core launcher layouts, focus engines, leanback assets, and Apple TV-inspired design principles originate from CleanYourTV. We extend our full credit, appreciation, and gratitude to [Gathin23](https://github.com/Gathin23) for creating and open-sourcing the premier native Apple TV launcher experience for Android TV.

A modular, lightweight debloat automation and remote-mapping framework for Android TV / Google TV, featuring a customized build of **[CleanYourTV](https://github.com/Gathin23/cleanyourtv)**.

Designed to support multiple TV brand models and series (e.g., **Hisense U7N**, **TCL 65Q6C**, **Walmart Onn 4K**) with zero friction—simply pass the TV model name.

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
└── tv/                     # Modular multi-device debloat & button configurations
    ├── common/
    │   └── common.debloat.txt  # Universal Google TV debloat (applied to all devices)
    ├── hisense/
    │   ├── u7n.debloat.txt     # Hisense U7N OEM bloat & background lockdown list
    │   └── u7n.buttons.txt     # Hisense remote button mappings (Quick Settings, app keys)
    ├── onn/
    │   ├── 4k_2023.debloat.txt # Onn 4K (2023) debloat list & optional streaming apps
    │   └── 4k_2023.buttons.txt # Onn remote button mappings
    └── tcl/
        ├── 65q6c.debloat.txt   # TCL 65Q6C / QM6 debloat list (Samba TV ACR, logkit, promo)
        └── 65q6c.buttons.txt   # TCL remote button mappings
```

---

## Two-Tier Scalable Debloat Architecture

To make debloating scalable across multiple TV brands (Hisense, TCL, Onn, Chromecast, Sony) without duplicating common packages:

1. **Universal Base Layer (`tv/common/common.debloat.txt`):**  
   Contains bloatware present on almost all modern Android TV / Google TV devices (Google telemetry/tracking, GTV auto-installers, Play Games/Videos, TalkBack/Switch Access conflicts, and stock YouTube/YouTube Music replaced by Tube). This file is automatically applied on every run.
2. **Device-Specific Layer (`tv/<brand>/<model>.debloat.txt`):**  
   Contains only manufacturer-specific bloatware, ACR tracking, and retail demo modes (e.g. Hisense `com.vt.*`, TCL `com.tcl.*`, Onn streaming apps).
3. **Remote Button Profiles (`tv/<brand>/<model>.buttons.txt`):**  
   Pairs with the target TV model to map remote keys (Settings, input toggles, app keys) to CleanYourTV features or preferred apps.

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
| `./setup.sh <tv_model> [tv_ip] [btn_profile]` | **Apply Setup:** Debloats TV, configures AdGuard DNS, installs custom launcher, deploys remote buttons, and runs verification. |
| `./setup.sh buttons <tv_model|btn_profile> [tv_ip]` | **Remote Buttons:** Configures remote buttons (Settings, inputs, app buttons) using a per-TV `.buttons.txt` profile without redebloating. |
| `./setup.sh discover [tv_ip] [tv_model]` | **Audit TV:** Scans installed packages on a TV and generates a categorized debloat candidate list under `tv/<brand>/<model>.debloat.txt`. |
| `./setup.sh verify [tv_ip]` | **Health Check:** Verifies Home launcher, DNS ad-blocking, AppOps starvation, remote services, and system RAM. |
| `./setup.sh` | **Interactive Menu:** Prompts with a numbered TV model selection menu. |
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
Run `setup.sh` from your computer, passing your TV model name and your TV's IP address:

```bash
# For Hisense U7N:
./setup.sh u7n 10.0.10.25

# For TCL 65Q6C:
./setup.sh 65q6c 10.0.10.26

# For Walmart Onn 4K (2023):
./setup.sh 4k_2023 10.0.10.27

# Optional: override with a custom button profile
./setup.sh u7n 10.0.10.25 custom_buttons
```

*(Arguments can be supplied in any order. The script automatically applies `tv/common/common.debloat.txt` as a universal base layer, the specified device debloat list, pairs the matching `.buttons.txt` config, takes a pre-flight snapshot in `backup/`, applies background lockdowns, configures AdGuard DNS, installs the custom launcher, grants coarse/fine location for weather, activates `SleepService` for instant standby and the sleep timer, and runs health verification).*

### Step 3: Secure Your TV
Once the script finishes:
1. Go back to **Developer options** on your TV.
2. Turn **USB debugging** back to **OFF**.
3. Reboot the TV. (This closes port 5555 and ensures your TV is completely secure).

> [!NOTE]
> **After System OTA Updates or Factory Reset:**  
> If an OTA firmware update resets your home screen or re-enables factory bloatware, simply re-enable USB debugging and run `./setup.sh u7n <ip>` again. Everything will be restored in seconds.

---

## Workflow 2: Automatic TV Package Discovery (`discover`)

When setting up a new TV (like your upcoming TCL TVs), you don't need to guess package names. Use the built-in auditor:

```bash
./setup.sh discover 10.0.10.26 c645
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

## Workflow 4: Per-TV Remote Button Mapping (`buttons`)

When stock Google TV (`launcherx`) is disabled, remotes that route special keys through Google TV (such as the **Settings / Gear** button or dedicated streaming app buttons) can become unmapped.

CleanYourTV resolves this by handling button mapping natively, configured via companion `tv/<brand>/<model>.buttons.txt` files:

### File Format (`tv/<brand>/<model>.buttons.txt`)
```text
# Remote Button Configuration
# Target Device: Hisense U7N (Google TV)

# Open Quick Settings glass panel (true) or full Android settings (false)
SETTINGS_PANEL=true

# Keycodes that open Settings / Quick Settings (e.g. 83 for Google TV / Hisense remote)
SETTINGS_KEYCODES=83

# Optional: Scancodes that open Settings (for remotes sending unmapped Linux scancodes)
# SETTINGS_SCANCODES=

# Optional: Keycodes that open Input Switcher
# INPUT_KEYCODES=178

# Optional: Dedicated App Buttons (format: KEYCODE:PACKAGE or KEYCODE_NAME:PACKAGE)
# APP_KEYS=190:com.google.android.youtube.tv
# APP_KEYS=191:com.netflix.ninja
```

### Applying Button Mappings
* **Automatic on Deploy:** When you run `./setup.sh <tv_model> <ip>`, `setup.sh` automatically checks for a matching `tv/<brand>/<model>.buttons.txt` and deploys it.
* **On-Demand Update:** To update remote buttons without re-running the full debloat process:
  ```bash
  ./setup.sh buttons u7n 10.0.10.25
  ```

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
./setup.sh u7n 10.0.10.25
```

---

## Security & Privacy Notice

* The `.gitignore` ensures all device backups (`backup/`), dumps, logs, and private keys remain local and are never committed to GitHub.
* No packages are permanently removed from the TV; everything is disabled via `pm disable-user --user 0` and can be re-enabled if needed.
* Always turn OFF USB debugging on the TV when setup is complete.
