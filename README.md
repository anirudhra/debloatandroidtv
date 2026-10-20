# Multi-Device Android TV Debloat & Custom Launcher Framework

A modular, lightweight debloat configuration and setup framework for Android TV / Google TV.

This repository stores personal customizations, device debloat profiles, automation scripts, and pre-built binaries. It replaces the stock ad-laden Google TV interface with a clean, responsive Apple TV 4K-style native launcher based on [CleanYourTV](https://github.com/Gathin23/cleanyourtv).

Designed to support multiple TV brand series (e.g., **Hisense U7 series**, **TCL TVs**) from a single unified framework.

---

## Repository Structure

```text
debloatandroidtv/
├── README.md               # Complete setup, build, and deployment guide
├── .gitignore              # Automatically excludes device backups & build artifacts
├── LICENSE                 # MIT License
├── setup.sh                # Multi-device one-click ADB setup script
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
└── devices/                # Device-specific debloat profiles
    ├── hisense_u7/         # Profile for Hisense U7 Series (SmartTV 4K FFM / hengshan)
    │   └── debloat-list.txt# Exact 19 telemetry, store demo & background bloat packages
    └── tcl/                # Profile for TCL Google TVs (C-Series, Q-Series, BeyondTV)
        └── debloat-list.txt# TCL telemetry, Samba TV ACR tracking, & promo packages
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
Run `setup.sh` from your computer, passing the TV profile and your TV's IP:

```bash
# For Hisense U7 series:
./setup.sh hisense_u7 10.0.10.25

# For TCL TVs:
./setup.sh tcl 10.0.10.26
```

*(If arguments are omitted, the script auto-detects the connected TV brand over ADB or prompts you with an interactive menu).*

### Step 3: Secure Your TV
Once the script finishes:
1. Go back to **Developer options** on your TV.
2. Turn **USB debugging** back to **OFF**.
3. Reboot the TV. (This closes port 5555 and ensures your TV is completely secure).

> [!NOTE]
> **After System OTA Updates or Factory Reset:**  
> If an OTA firmware update resets your home screen or re-enables factory bloatware, simply re-enable USB debugging and run `./setup.sh <profile> <ip>` again. Everything will be restored in seconds.

---

## Workflow 2: Clone Upstream, Merge Customizations, Build & Deploy

If you want to pull updates from upstream [CleanYourTV](https://github.com/Gathin23/cleanyourtv), recompile the launcher, or make further modifications:

### Step 1: Clone the Upstream Repository
Clone the original CleanYourTV repo alongside this repository (e.g., in `~/code/github`):

```bash
cd ~/code/github
git clone https://github.com/Gathin23/cleanyourtv.git
```

### Step 2: Merge Your Customizations
Run the included helper script to copy your custom code, icons, and layouts into the cloned repo:

```bash
cd ~/code/github/debloatandroidtv
./apply_to_cleanyourtv.sh ../cleanyourtv
```

*Alternative (Manual Git Patch):*
```bash
cd ~/code/github/cleanyourtv
git apply ../debloatandroidtv/customizations/launcher.patch
```

### Step 3: Build the Custom Release APK
You can build the APK automatically with `--build`:

```bash
cd ~/code/github/debloatandroidtv
./apply_to_cleanyourtv.sh ../cleanyourtv --build
```
*(This automatically runs `./gradlew assembleRelease` and updates `bin/tvhome.apk`).*

*Or manually:*
```bash
cd ~/code/github/cleanyourtv/launcher
./gradlew assembleRelease
cp app/build/outputs/apk/release/app-release.apk ~/code/github/debloatandroidtv/bin/tvhome.apk
```

### Step 4: Deploy the Newly Built Launcher to Your TV
Deploy using `setup.sh`:

```bash
cd ~/code/github/debloatandroidtv
./setup.sh hisense_u7 10.0.10.25
```

---

## Multi-Device Framework: Managing & Adding TV Profiles

Debloat lists are decoupled into independent profiles under `devices/`:

```text
devices/
├── hisense_u7/
│   └── debloat-list.txt
└── tcl/
    └── debloat-list.txt
```

### Adding a New TV Profile (e.g. `tcl_bedroom` or `sony_bravia`)
1. Create a new directory inside `devices/`:
   ```bash
   mkdir -p devices/tcl_bedroom
   ```
2. Create `devices/tcl_bedroom/debloat-list.txt` with package names to disable (one per line, `#` comments supported):
   ```text
   # Telemetry
   com.tcl.ttvs
   com.tcl.logkit
   ```
3. Deploy to that TV anytime:
   ```bash
   ./setup.sh tcl_bedroom <tv_ip>
   ```

### Profile Auto-Detection
When you run `./setup.sh` without specifying a profile, the script checks the TV hardware over ADB:
* If the TV reports brand `Hisense`, it automatically chooses `hisense_u7`.
* If the TV reports brand `TCL`, it automatically chooses `tcl`.
* Otherwise, it presents an interactive selection menu.

---

## Security & Privacy Notice

* The `.gitignore` ensures all device backups (`backup/`), dumps, logs, and private keys remain local and are never committed to GitHub.
* No packages are permanently removed from the TV; everything is disabled via `pm disable-user --user 0` and can be re-enabled if needed.
* Always turn OFF USB debugging on the TV when setup is complete.
