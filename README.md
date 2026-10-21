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
│   ├── MainActivity.java   # Full-grid ambient glow & icon-only Wi-Fi logic
│   ├── activity_main.xml   # Clean status bar & icon-only pill layouts
│   ├── config.xml          # Tube rename, YouTube banner, and 4 dock apps
│   ├── strings.xml         # 2-row date format (Day of week / Date & Month)
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

* **Full-Grid Dynamic Ambient Glow:** Samples dominant colors from every app's artwork and casts a smooth ambient glow as you scroll through the entire grid, not just the dock row.
* **Custom App Branding:** TizenTube is prominently titled **Tube** and uses the official YouTube Leanback icon (persists across TizenTube updates).
* **Pinned Dock:** Dedicated bottom dock containing Tube, Apple TV, Amazon Prime Video, and LocalNow.
* **Refined Status Bar:**
  * Clean thin clock (Outfit font) with greeting text removed.
  * Date formatted cleanly into 2 rows (Row 1: Day of week, Row 2: Date & Month).
  * Status pills: `Inputs` (with icon and text), `Wi-Fi` (icon-only circular pill with offline detection), and `Settings` (icon-only circular pill).

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

*(Arguments can be supplied in any order. The script automatically takes a pre-flight snapshot in `backup/`, applies the debloat & background lockdowns, configures AdGuard DNS, installs the launcher, and runs health verification).*

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

If you want to pull updates from upstream [CleanYourTV](https://github.com/Gathin23/cleanyourtv), recompile the launcher, or make further modifications:

### Step 1: Clone Upstream
```bash
cd ~/code/github
git clone https://github.com/Gathin23/cleanyourtv.git
```

### Step 2: Merge Your Customizations
```bash
cd ~/code/github/debloatandroidtv
./apply_to_cleanyourtv.sh ../cleanyourtv
```

### Step 3: Build Release APK
```bash
cd ~/code/github/debloatandroidtv
./apply_to_cleanyourtv.sh ../cleanyourtv --build
```
*(Automatically builds with `./gradlew assembleRelease` and updates `bin/tvhome.apk`).*

### Step 4: Deploy to Your TV
```bash
./setup.sh tv/hisense/u7n.txt 10.0.10.25
```

---

## Security & Privacy Notice

* The `.gitignore` ensures all device backups (`backup/`), dumps, logs, and private keys remain local and are never committed to GitHub.
* No packages are permanently removed from the TV; everything is disabled via `pm disable-user --user 0` and can be re-enabled if needed.
* Always turn OFF USB debugging on the TV when setup is complete.
