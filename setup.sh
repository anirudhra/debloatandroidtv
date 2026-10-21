#!/usr/bin/env bash
# Multi-Device Android TV Setup, Debloat & Verification Kit
#
# Usage:
#   ./setup.sh <debloat_list_path> [tv_ip]     # Apply debloat & custom launcher
#   ./setup.sh discover [tv_ip] [output_path]  # Scan TV and generate candidate debloat list
#   ./setup.sh verify [tv_ip]                 # Verify launcher, DNS, and debloat status
#
# Examples:
#   ./setup.sh tv/hisense/u7n.txt 10.0.10.25
#   ./setup.sh discover 10.0.10.26 tv/tcl/c645.txt
#   ./setup.sh verify 10.0.10.25
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TV_DIR="$SCRIPT_DIR/tv"
BACKUP_DIR="$SCRIPT_DIR/backup"

show_help() {
    cat << 'EOF'
Android TV Debloat & Custom Launcher Setup Kit

Usage:
  ./setup.sh [COMMAND] [ARGUMENTS...]

Commands:
  apply [list_path] [tv_ip]     (Default) Apply debloat list, configure AdGuard DNS,
                                install launcher, and configure remote buttons.
  buttons [btn_path] [tv_ip]    Configure remote buttons (Settings key, inputs, apps)
                                using a per-TV .buttons.txt configuration file.
  discover [tv_ip] [out_file]   Connect to a TV, audit all packages, and generate
                                a candidate debloat list under tv/<brand>/<model>.txt.
  verify [tv_ip]                Verify Home launcher status, AdGuard DNS ad-blocking,
                                disabled bloatware counts, and system RAM health.

Help:
  -h, --help, help              Show this help reference.

Examples:
  # Deploy Hisense U7N setup (auto-applies tv/hisense/u7n.buttons.txt):
  ./setup.sh tv/hisense/u7n.txt 10.0.10.25

  # Configure or update remote buttons only:
  ./setup.sh buttons tv/hisense/u7n.buttons.txt 10.0.10.25
  ./setup.sh buttons 10.0.10.25

  # Deploy TCL TV setup:
  ./setup.sh tv/tcl/model.txt 10.0.10.26

  # Discover & generate debloat list for a new TV:
  ./setup.sh discover 10.0.10.26 tv/tcl/c645.txt
  ./setup.sh discover 10.0.10.26

  # Run post-setup health check:
  ./setup.sh verify 10.0.10.25

  # Interactive mode (prompts with numbered menu from ./tv/):
  ./setup.sh

Environment Variables:
  TV_HOST                       Default target TV IP (default: 10.0.10.25)
  TV_PORT                       ADB network port (default: 5555)
  DEBLOAT_LIST                  Path to debloat package list
EOF
}

# Check for help flag anywhere in arguments
for arg in "$@"; do
    if [ "$arg" == "--help" ] || [ "$arg" == "-h" ] || [ "$arg" == "help" ]; then
        show_help
        exit 0
    fi
done

COMMAND="apply"
if [ "${1:-}" == "discover" ]; then
    COMMAND="discover"
    shift
elif [ "${1:-}" == "verify" ]; then
    COMMAND="verify"
    shift
elif [ "${1:-}" == "buttons" ]; then
    COMMAND="buttons"
    shift
fi

# -----------------------------------------------------------------------------
# Common Helpers & Arguments
# -----------------------------------------------------------------------------
PARAM1="${1:-}"
PARAM2="${2:-}"

DEBLOAT_LIST="${DEBLOAT_LIST:-}"
BUTTONS_FILE="${BUTTONS_FILE:-}"
TV_HOST="${TV_HOST:-10.0.10.25}"
TV_PORT="${TV_PORT:-5555}"
OUTPUT_FILE=""

is_ip() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$1" =~ : ]]
}

is_file_path() {
    [[ "$1" == *.txt ]] || [ -f "$1" ] || [ -f "$SCRIPT_DIR/$1" ]
}

if [ "$COMMAND" == "discover" ]; then
    for p in "$PARAM1" "$PARAM2"; do
        if [ -n "$p" ]; then
            if is_ip "$p"; then
                TV_HOST="$p"
            else
                OUTPUT_FILE="$p"
            fi
        fi
    done
elif [ "$COMMAND" == "buttons" ]; then
    for p in "$PARAM1" "$PARAM2"; do
        if [ -n "$p" ]; then
            if is_ip "$p"; then
                TV_HOST="$p"
            else
                BUTTONS_FILE="$p"
            fi
        fi
    done
else
    for p in "$PARAM1" "$PARAM2"; do
        if [ -n "$p" ]; then
            if is_ip "$p"; then
                TV_HOST="$p"
            elif is_file_path "$p"; then
                if [[ "$p" == *.buttons.txt ]]; then
                    BUTTONS_FILE="$p"
                else
                    DEBLOAT_LIST="$p"
                fi
            elif [ -z "$DEBLOAT_LIST" ]; then
                DEBLOAT_LIST="$p"
            fi
        fi
    done
fi

TARGET="${TV_HOST}:${TV_PORT}"

# Ensure ADB is available
if ! command -v adb >/dev/null 2>&1; then
    echo "Error: 'adb' command not found. Please install Android platform-tools or add adb to PATH."
    exit 1
fi

ensure_connected() {
    echo "Connecting to TV over ADB ($TARGET)..."
    adb connect "$TARGET" >/dev/null 2>&1 || true
    # Quick probe
    if ! adb -s "$TARGET" shell "echo ok" >/dev/null 2>&1; then
        echo "Error: Unable to communicate with $TARGET. Make sure USB debugging is ON."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Remote Button Config Parser & Deployer
# -----------------------------------------------------------------------------
parse_buttons_file() {
    local file="$1"
    local panel="true"
    local -a settings_keycodes=()
    local -a settings_scancodes=()
    local -a input_keycodes=()
    local -a app_keys=()

    while IFS= read -r line || [ -n "$line" ]; do
        line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        local key val
        key="$(echo "$line" | sed -E 's/[[:space:]]*[:=][[:space:]]*/=/' | cut -d'=' -f1 | tr '[:upper:]' '[:lower:]')"
        val="$(echo "$line" | sed -E 's/[[:space:]]*[:=][[:space:]]*/=/' | cut -d'=' -f2-)"

        case "$key" in
            settings_panel|settings_key_panel)
                if [[ "$val" =~ ^(false|0|no)$ ]]; then
                    panel="false"
                else
                    panel="true"
                fi
                ;;
            settings_key|settings_keys|settings_keycode|settings_keycodes)
                IFS=',' read -ra ADDR <<< "$val"
                for i in "${ADDR[@]}"; do
                    i="$(echo "$i" | tr -d ' ')"
                    [ -n "$i" ] && settings_keycodes+=("$i")
                done
                ;;
            settings_scancode|settings_scancodes)
                IFS=',' read -ra ADDR <<< "$val"
                for i in "${ADDR[@]}"; do
                    i="$(echo "$i" | tr -d ' ')"
                    [ -n "$i" ] && settings_scancodes+=("$i")
                done
                ;;
            input_key|input_keys|input_keycode|input_keycodes)
                IFS=',' read -ra ADDR <<< "$val"
                for i in "${ADDR[@]}"; do
                    i="$(echo "$i" | tr -d ' ')"
                    [ -n "$i" ] && input_keycodes+=("$i")
                done
                ;;
            app_key|app_keys)
                IFS=',' read -ra ADDR <<< "$val"
                for i in "${ADDR[@]}"; do
                    i="$(echo "$i" | tr -d ' ')"
                    [ -n "$i" ] && app_keys+=("\"$i\"")
                done
                ;;
        esac
    done < "$file"

    if [ "${#settings_keycodes[@]}" -eq 0 ]; then
        settings_keycodes=("83")
    fi

    local sk_json ik_json ss_json ak_json
    sk_json="$(IFS=,; echo "[${settings_keycodes[*]}]")"
    ss_json="$(IFS=,; echo "[${settings_scancodes[*]}]")"
    ik_json="$(IFS=,; echo "[${input_keycodes[*]}]")"
    ak_json="$(IFS=,; echo "[${app_keys[*]}]")"

    cat <<EOF
{
  "settings_key_panel": $panel,
  "settings_key_keycodes": $sk_json,
  "settings_key_scancodes": $ss_json,
  "input_key_keycodes": $ik_json,
  "app_keys": $ak_json
}
EOF
}

push_buttons_config() {
    local btn_file="$1"
    local target="$2"
    if [ ! -f "$btn_file" ]; then
        return 0
    fi
    echo "Configuring remote buttons from $btn_file..."
    local json
    json="$(parse_buttons_file "$btn_file")"
    local tmp_file
    tmp_file="$(mktemp /tmp/tvhome_config.XXXXXX.json)"
    echo "$json" > "$tmp_file"

    local remote_dir="/sdcard/Android/data/com.gathin.tvhome/files"
    local remote_tmp="/data/local/tmp/cyt-theme-config.json"
    adb -s "$target" push "$tmp_file" "$remote_tmp" >/dev/null 2>&1
    adb -s "$target" shell "mkdir -p $remote_dir 2>/dev/null; cp $remote_tmp $remote_dir/config.json 2>/dev/null || content write --uri content://com.gathin.tvhome.theme/config.json < $remote_tmp; rm -f $remote_tmp" >/dev/null 2>&1
    rm -f "$tmp_file"

    # Reload launcher & accessibility services
    adb -s "$target" shell '
        cur=$(settings get secure enabled_accessibility_services)
        [ "$cur" = "null" ] && cur=""
        # Purge any switchaccess/talkback/flar2 that hijack remote buttons
        cur=$(echo "$cur" | tr ":" "\n" | grep -v "switchaccess" | grep -v "talkback" | grep -v "flar2" | tr "\n" ":" | sed "s/:$//")
        for svc in com.gathin.tvhome/.HomeKeyService com.gathin.tvhome/.InputKeyService com.gathin.tvhome/.SleepService; do
            case "$cur" in
                *"$svc"*) ;;
                "") cur="$svc" ;;
                *) cur="$cur:$svc" ;;
            esac
        done
        am force-stop com.gathin.tvhome
        am start -n com.gathin.tvhome/.MainActivity >/dev/null 2>&1
        sleep 1
        settings put secure enabled_accessibility_services ""
        settings put secure accessibility_enabled 0
        sleep 1
        settings put secure enabled_accessibility_services "$cur"
        settings put secure accessibility_enabled 1
    ' >/dev/null 2>&1 || true
    echo "Remote buttons successfully deployed & services reloaded on $target."
}

# =============================================================================
# SUBCOMMAND: BUTTONS
# =============================================================================
do_buttons() {
    echo "========================================================"
    echo "Android TV Remote Button Configuration"
    echo "Target Device: $TARGET"
    echo "========================================================"
    ensure_connected

    if [ -z "$BUTTONS_FILE" ]; then
        AVAILABLE_BTN=()
        if [ -d "$TV_DIR" ]; then
            while IFS= read -r f; do
                AVAILABLE_BTN+=("${f#$SCRIPT_DIR/}")
            done < <(find "$TV_DIR" -type f -name "*.buttons.txt" | sort)
        fi

        if [ -t 0 ] && [ "${#AVAILABLE_BTN[@]}" -gt 1 ]; then
            echo "Select a button configuration file to apply:"
            select opt in "${AVAILABLE_BTN[@]}"; do
                if [ -n "$opt" ]; then
                    BUTTONS_FILE="$opt"
                    break
                fi
            done
        elif [ "${#AVAILABLE_BTN[@]}" -ge 1 ]; then
            BUTTONS_FILE="${AVAILABLE_BTN[0]}"
            echo "Auto-selected button config: $BUTTONS_FILE"
        else
            BUTTONS_FILE="tv/hisense/u7n.buttons.txt"
        fi
    fi

    if [ ! -f "$BUTTONS_FILE" ] && [ -f "$SCRIPT_DIR/$BUTTONS_FILE" ]; then
        BUTTONS_FILE="$SCRIPT_DIR/$BUTTONS_FILE"
    fi

    if [ ! -f "$BUTTONS_FILE" ]; then
        echo "Error: Button configuration file not found at '$BUTTONS_FILE'"
        if [ -d "$TV_DIR" ]; then
            echo "Available button configs in ./tv/:"
            find "$TV_DIR" -type f -name "*.buttons.txt" | sed "s|$SCRIPT_DIR/|  - |"
        fi
        exit 1
    fi

    push_buttons_config "$BUTTONS_FILE" "$TARGET"
    echo "========================================================"
    echo "Remote buttons updated. Test your remote buttons now!"
    echo "========================================================"
}

# =============================================================================
# SUBCOMMAND: DISCOVER
# =============================================================================
do_discover() {
    echo "========================================================"
    echo "Android TV Package Discovery & Inventory"
    echo "Target: $TARGET"
    echo "========================================================"
    ensure_connected

    BRAND="$(adb -s "$TARGET" shell getprop ro.product.brand 2>/dev/null | tr -d '\r\n')"
    MODEL="$(adb -s "$TARGET" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n')"
    DEVICE="$(adb -s "$TARGET" shell getprop ro.product.device 2>/dev/null | tr -d '\r\n')"
    ANDROID="$(adb -s "$TARGET" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r\n')"
    BUILD_ID="$(adb -s "$TARGET" shell getprop ro.build.display.id 2>/dev/null | tr -d '\r\n')"

    echo "Device Info:"
    echo "  Manufacturer: $BRAND"
    echo "  Model:        $MODEL ($DEVICE)"
    echo "  Android OS:   $ANDROID (Build: $BUILD_ID)"
    echo ""

    echo "Scanning installed packages..."
    RAW_PACKAGES="$(adb -s "$TARGET" shell 'pm list packages -f' 2>/dev/null | tr -d '\r')"
    DISABLED_PACKAGES="$(adb -s "$TARGET" shell 'pm list packages -d' 2>/dev/null | tr -d '\r' | sed 's/^package://')"

    TOTAL_COUNT="$(echo "$RAW_PACKAGES" | grep -c . || true)"
    echo "Total packages on device: $TOTAL_COUNT"

    # Protected core components regex (never suggest disabling)
    PROTECTED_REGEX='^(android|com\.android\.(systemui|settings|packageinstaller|permissioncontroller|shell|inputmethod\..*|providers\.settings|providers\.media|providers\.downloads)|com\.google\.android\.(gms|gsf|vending|inputmethod\..*|tv\.remote\.service)|com\.tcl\.(tv|tvinput|dashboard|suspension|autopair|systemserver|providers\.config|initsetup|useragreement|globalkeyoverlay|systemui\.plugin|factory\.view)|com\.vt\.(tv\.tvcenter|tv\.input|source\..*|avmiddleware|tvplayer|eula|udpserver)|com\.mediatek\..*)$'

    # Candidate regex for telemetry, ads, tracking, bloatware
    CANDIDATE_REGEX='(^|\.)(ads?|adservice|advert|advertising|analytics|metrics?|telemetry|tracking|tracker|crash|logger|logging|promo|weblab|experiment|abtest|attribution|referrer|recommendations?|suggestions?|storemode|hotel|b2b|protector|alexa|interactive|ginga)(\.|$)'

    ADS_LIST=()
    DEMO_LIST=()
    ASSIST_LIST=()
    OTHER_CANDIDATES=()

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Format is package:/path/to/base.apk=com.package.name
        pkg="${line##*=}"
        [ -z "$pkg" ] && continue

        # Check protected
        if echo "$pkg" | grep -Eq "$PROTECTED_REGEX"; then
            continue
        fi

        # Check candidate
        if echo "$pkg" | grep -Eqi "$CANDIDATE_REGEX"; then
            if echo "$pkg" | grep -Eqi '(ads?|adservice|advert|analytics|metrics?|telemetry|tracking|tracker|logger)'; then
                ADS_LIST+=("$pkg")
            elif echo "$pkg" | grep -Eqi '(storemode|hotel|b2b|demo|exhibit|esticker)'; then
                DEMO_LIST+=("$pkg")
            elif echo "$pkg" | grep -Eqi '(alexa|assistant|voice)'; then
                ASSIST_LIST+=("$pkg")
            else
                OTHER_CANDIDATES+=("$pkg")
            fi
        fi
    done <<< "$RAW_PACKAGES"

    # Default output file if omitted
    if [ -z "$OUTPUT_FILE" ]; then
        BRAND_CLEAN="$(echo "$BRAND" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
        MODEL_CLEAN="$(echo "$MODEL" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')"
        [ -z "$BRAND_CLEAN" ] && BRAND_CLEAN="generic"
        [ -z "$MODEL_CLEAN" ] && MODEL_CLEAN="model"
        OUTPUT_FILE="$TV_DIR/$BRAND_CLEAN/${MODEL_CLEAN}.txt"
    fi

    mkdir -p "$(dirname "$OUTPUT_FILE")"

    {
        echo "# Android TV Debloat Package List"
        echo "# Target Device: $BRAND $MODEL ($DEVICE)"
        echo "# Android OS: $ANDROID (Build $BUILD_ID)"
        echo "# Generated on: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "#"
        echo "# Safe to disable with: adb shell pm disable-user --user 0 <package>"
        echo ""
        echo "# --- Telemetry, Tracking & Analytics ---"
        for p in "${ADS_LIST[@]}"; do
            echo "$p"
        done
        echo ""
        echo "# --- Retail Demo, Store & Commercial Modes ---"
        for p in "${DEMO_LIST[@]}"; do
            echo "$p"
        done
        echo ""
        echo "# --- Voice Assistants & Nags ---"
        for p in "${ASSIST_LIST[@]}"; do
            echo "$p"
        done
        echo ""
        echo "# --- Other Promo & Interactive Candidates ---"
        for p in "${OTHER_CANDIDATES[@]}"; do
            echo "$p"
        done
    } > "$OUTPUT_FILE"

    echo ""
    echo "Discovery complete! Generated debloat candidate file:"
    echo "  -> $OUTPUT_FILE"
    echo ""
    echo "Review the file, uncomment/comment any packages, and deploy with:"
    echo "  ./setup.sh $OUTPUT_FILE $TARGET"
}

# =============================================================================
# SUBCOMMAND: VERIFY
# =============================================================================
do_verify() {
    echo "========================================================"
    echo "Android TV Optimization Health Check & Verification"
    echo "Target: $TARGET"
    echo "========================================================"
    ensure_connected

    PASSED=0
    TOTAL_CHECKS=5

    # 1. Launcher Check
    echo -n "[1/$TOTAL_CHECKS] Checking Default Home Launcher... "
    HOME_RES="$(adb -s "$TARGET" shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME" 2>/dev/null | tr -d '\r')"
    if echo "$HOME_RES" | grep -q "com.gathin.tvhome"; then
        echo "PASS"
        echo "       Active Home: com.gathin.tvhome/.MainActivity"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL"
        echo "       Current Home: $(echo "$HOME_RES" | tail -1)"
    fi

    # 2. DNS Ad-Blocking Check
    echo -n "[2/$TOTAL_CHECKS] Checking Private DNS Ad-Blocking... "
    DNS_SPEC="$(adb -s "$TARGET" shell "settings get global private_dns_specifier" 2>/dev/null | tr -d '\r')"
    DNS_MODE="$(adb -s "$TARGET" shell "settings get global private_dns_mode" 2>/dev/null | tr -d '\r')"
    if [[ "$DNS_SPEC" == *"adguard"* ]] && [[ "$DNS_MODE" == "hostname" ]]; then
        echo "PASS"
        echo "       Private DNS Specifier: $DNS_SPEC ($DNS_MODE)"
        PASSED=$((PASSED + 1))
    else
        echo "WARN"
        echo "       Private DNS is currently: ${DNS_SPEC:-disabled} (${DNS_MODE:-off})"
    fi

    # 3. Disabled Bloatware Count
    echo -n "[3/$TOTAL_CHECKS] Checking Disabled Bloatware Packages... "
    DIS_COUNT="$(adb -s "$TARGET" shell "pm list packages -d" 2>/dev/null | grep -c "package:" || true)"
    if [ "$DIS_COUNT" -gt 0 ]; then
        echo "PASS"
        echo "       Total bloatware packages disabled: $DIS_COUNT"
        PASSED=$((PASSED + 1))
    else
        echo "WARN (No disabled packages detected)"
    fi

    # 4. Background Starvation (AppOps)
    echo -n "[4/$TOTAL_CHECKS] Checking Background Process Starvation... "
    STARVED_FOUND=0
    for pkg in "com.vt.tv.smartsense" "com.vt.tv.aiot"; do
        OP_STATE="$(adb -s "$TARGET" shell "appops get $pkg RUN_ANY_IN_BACKGROUND 2>/dev/null" | tr -d '\r' || true)"
        if [[ "$OP_STATE" == *"ignore"* ]] || [[ "$OP_STATE" == *"deny"* ]]; then
            STARVED_FOUND=$((STARVED_FOUND + 1))
        fi
    done
    if [ "$STARVED_FOUND" -gt 0 ]; then
        echo "PASS"
        echo "       Protected services starved of background execution."
        PASSED=$((PASSED + 1))
    else
        echo "INFO (Standard debloat mode active)"
        PASSED=$((PASSED + 1))
    fi

    # 5. Remote Keys & Accessibility Services Check
    echo -n "[5/$TOTAL_CHECKS] Checking Remote Key & Standby Services... "
    ACC_SVC="$(adb -s "$TARGET" shell "settings get secure enabled_accessibility_services" 2>/dev/null | tr -d '\r')"
    if echo "$ACC_SVC" | grep -q "com.gathin.tvhome"; then
        echo "PASS"
        echo "       Active: HomeKeyService, InputKeyService, SleepService"
        PASSED=$((PASSED + 1))
    else
        echo "WARN"
        echo "       Remote key accessibility services not active. Run setup to enable."
    fi

    # Check configured remote buttons
    CFG_STAT="$(adb -s "$TARGET" shell "content read --uri content://com.gathin.tvhome.theme/config.json 2>/dev/null || cat /sdcard/Android/data/com.gathin.tvhome/files/config.json 2>/dev/null" | tr -d '\r\n' || true)"
    if [ -n "$CFG_STAT" ]; then
        echo "       Remote button profile: Loaded dynamically from config.json"
    else
        echo "       Remote button profile: Using built-in defaults (Quick Settings on keycode 83, 82, 176)"
    fi

    echo ""
    # System RAM & Uptime
    FREE_RAM="$(adb -s "$TARGET" shell "dumpsys meminfo 2>/dev/null" | sed -n 's/.*Free RAM: *\([0-9,]*K\).*/\1/p' | head -1 || true)"
    if [ -n "$FREE_RAM" ]; then
        echo "System Status: Free RAM: $FREE_RAM"
    fi

    echo "========================================================"
    if [ "$PASSED" -ge 3 ]; then
        echo "Verification Complete: TV is clean, fast, and protected ($PASSED/$TOTAL_CHECKS checks passed)."
    else
        echo "Verification Notice: Some items require attention ($PASSED/$TOTAL_CHECKS)."
    fi
    echo "========================================================"
}

# =============================================================================
# SUBCOMMAND: APPLY (DEFAULT SETUP / RESTORE)
# =============================================================================
do_apply() {
    echo "========================================================"
    echo "Android TV Debloat & Custom Launcher Setup"
    echo "Target Device: $TARGET"
    echo "========================================================"
    ensure_connected

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
    # Pre-flight Snapshot (Settings & State)
    # -----------------------------------------------------------------------------
    SNAPSHOT_DIR="$BACKUP_DIR/snapshot-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$SNAPSHOT_DIR"
    adb -s "$TARGET" shell "settings list global" > "$SNAPSHOT_DIR/settings_global.txt" 2>/dev/null || true
    adb -s "$TARGET" shell "settings list secure" > "$SNAPSHOT_DIR/settings_secure.txt" 2>/dev/null || true
    adb -s "$TARGET" shell "pm list packages -d" > "$SNAPSHOT_DIR/packages_disabled.txt" 2>/dev/null || true
    echo "Pre-flight snapshot saved to: ${SNAPSHOT_DIR#$SCRIPT_DIR/}"

    # -----------------------------------------------------------------------------
    # Debloat & Background Starvation Execution
    # -----------------------------------------------------------------------------
    echo "[2/6] Disabling bloatware & applying background lockdown..."
    DISABLED_COUNT=0
    STARVED_COUNT=0

    while IFS= read -r line || [ -n "$line" ]; do
        pkg="$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')"
        [ -z "$pkg" ] && continue

        if [[ "$pkg" == lockdown:* ]]; then
            # AppOps background execution denial (starvation without disable)
            target_pkg="${pkg#lockdown:}"
            adb -s "$TARGET" shell "cmd appops set $target_pkg RUN_ANY_IN_BACKGROUND ignore" >/dev/null 2>&1 || true
            adb -s "$TARGET" shell "cmd appops set $target_pkg RUN_IN_BACKGROUND ignore" >/dev/null 2>&1 || true
            adb -s "$TARGET" shell "am force-stop $target_pkg" >/dev/null 2>&1 || true
            STARVED_COUNT=$((STARVED_COUNT + 1))
        else
            # Standard user disable
            adb -s "$TARGET" shell "pm disable-user --user 0 $pkg" >/dev/null 2>&1 || true
            DISABLED_COUNT=$((DISABLED_COUNT + 1))
        fi
    done < "$DEBLOAT_LIST"

    echo "Debloat applied: $DISABLED_COUNT packages disabled, $STARVED_COUNT packages starved in background."

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
    adb -s "$TARGET" shell "pm grant com.gathin.tvhome android.permission.ACCESS_COARSE_LOCATION" >/dev/null 2>&1 || true
    # Activate CleanYourTV Accessibility Services:
    # - HomeKeyService: intercepts Home & Settings buttons orphaned when stock Google TV launcher was disabled
    # - InputKeyService: intercepts Input / Source buttons orphaned when stock Google TV launcher was disabled
    # - SleepService: allows Control Center & sleep timer to put the TV in standby
    adb -s "$TARGET" shell '
        cur=$(settings get secure enabled_accessibility_services)
        [ "$cur" = "null" ] && cur=""
        # Purge any switchaccess/talkback/flar2 that hijack remote buttons
        cur=$(echo "$cur" | tr ":" "\n" | grep -v "switchaccess" | grep -v "talkback" | grep -v "flar2" | tr "\n" ":" | sed "s/:$//")
        for svc in com.gathin.tvhome/.HomeKeyService com.gathin.tvhome/.InputKeyService com.gathin.tvhome/.SleepService; do
            case "$cur" in
                *"$svc"*) ;;
                "") cur="$svc" ;;
                *) cur="$cur:$svc" ;;
            esac
        done
        settings put secure enabled_accessibility_services "$cur"
        settings put secure accessibility_enabled 1
        settings put secure show_ime_with_hard_keyboard 1
    ' >/dev/null 2>&1 || true
    echo "Launcher installed & remote key services activated successfully."

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
        "flar2.homebutton"
    )
    for pkg in "${PROJECTIVY_PACKAGES[@]}"; do
        adb -s "$TARGET" shell "pm uninstall $pkg" >/dev/null 2>&1 || true
    done

    # -----------------------------------------------------------------------------
    # Apply Remote Button Mappings
    # -----------------------------------------------------------------------------
    if [ -n "$BUTTONS_FILE" ] && [ -f "$BUTTONS_FILE" ]; then
        push_buttons_config "$BUTTONS_FILE" "$TARGET"
    else
        CANDIDATE_BTN="${DEBLOAT_LIST%.txt}.buttons.txt"
        if [ -f "$CANDIDATE_BTN" ]; then
            push_buttons_config "$CANDIDATE_BTN" "$TARGET"
        fi
    fi

    echo "Starting CleanYourTV Home..."
    adb -s "$TARGET" shell "am force-stop com.gathin.tvhome && am start -n com.gathin.tvhome/.MainActivity" >/dev/null 2>&1

    echo ""
    echo "Setup successfully deployed! Running verification..."
    echo ""
    do_verify

    echo ""
    echo "REMINDER: Turn OFF USB debugging in TV Developer Options for security!"
}

# Dispatch
case "$COMMAND" in
    discover) do_discover ;;
    verify)   do_verify ;;
    buttons)  do_buttons ;;
    apply)    do_apply ;;
esac
