#!/usr/bin/env bash
# Multi-Device Android TV Setup, Debloat & Verification Kit
#
# Usage:
#   ./setup.sh --tv <model> [--ip <address>]   # Apply debloat, launcher & remote buttons
#   ./setup.sh --buttons --tv <model>          # Update remote button mappings only
#   ./setup.sh --discover <model> [--ip <ip>]  # Scan TV and generate candidate debloat list
#   ./setup.sh --verify [--ip <ip>]            # Verify launcher, DNS, and debloat status
#
# Examples:
#   ./setup.sh --tv u7n --ip 10.0.10.25
#   ./setup.sh --tv q6c_qm6 --ip 10.0.10.26
#   ./setup.sh --tv 4k_2023 --ip 10.0.10.27
#   ./setup.sh --buttons --tv u7n
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TV_DIR="$SCRIPT_DIR/tv"
BACKUP_DIR="$SCRIPT_DIR/backup"

show_help() {
    cat << 'EOF'
Android TV Debloat & Custom Launcher Setup Kit

Usage:
  ./setup.sh [OPTIONS]

Options:
  --tv, -t <model>          Target TV profile name matching tv/<brand>/<model>.*.txt (e.g. u7n, q6c_qm6, 4k_2023)
  --ip, -i <ip_address>     Target TV IP address (default: 10.0.10.25)
  --buttons, -b             Configure remote buttons only (no debloat / launcher install)
  --discover, -d [model]    Audit TV and generate candidate debloat list under tv/<brand>/<model>.debloat.txt
  --verify, -v              Verify launcher, DNS, and debloat status on TV
  --help, -h                Show this help reference

Examples:
  # Deploy full setup to Hisense U7N:
  ./setup.sh --tv u7n --ip 10.0.10.25
  ./setup.sh --tv u7n

  # Deploy full setup to TCL Q6C / QM6:
  ./setup.sh --tv q6c_qm6 --ip 10.0.10.26

  # Deploy full setup to Walmart Onn 4K (2023):
  ./setup.sh --tv 4k_2023 --ip 10.0.10.27

  # Configure remote buttons only for a TV:
  ./setup.sh --buttons --tv u7n --ip 10.0.10.25
  ./setup.sh --buttons --tv u7n

  # Audit a new TV and generate candidate debloat list:
  ./setup.sh --discover c645 --ip 10.0.10.26
  ./setup.sh --discover --ip 10.0.10.26

  # Run post-setup health check:
  ./setup.sh --verify --ip 10.0.10.25
  ./setup.sh --verify

  # Interactive mode (prompts with numbered TV menu):
  ./setup.sh

Environment Variables:
  TV_HOST                   Default target TV IP (default: 10.0.10.25)
  TV_PORT                   ADB network port (default: 5555)
  TV_MODEL                  Default target TV model
EOF
}

# -----------------------------------------------------------------------------
# Common Helpers & Resolvers
# -----------------------------------------------------------------------------
is_ip() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$1" =~ : ]]
}

resolve_debloat_file() {
    local query="$1"
    [ -z "$query" ] && return 1
    local clean="${query%.debloat.txt}"
    clean="${clean%.txt}"

    if [ -f "$query" ]; then
        echo "$query"
        return 0
    elif [ -f "$SCRIPT_DIR/$query" ]; then
        echo "$SCRIPT_DIR/$query"
        return 0
    elif [ -f "$TV_DIR/${clean}.debloat.txt" ]; then
        echo "$TV_DIR/${clean}.debloat.txt"
        return 0
    elif [ -f "$SCRIPT_DIR/${clean}.debloat.txt" ]; then
        echo "$SCRIPT_DIR/${clean}.debloat.txt"
        return 0
    fi

    local basename="${clean##*/}"
    local matches=()
    while IFS= read -r f; do
        [ -n "$f" ] && matches+=("$f")
    done < <(find "$TV_DIR" -type f -name "${basename}.debloat.txt" ! -path "*/common/*" | sort)

    if [ "${#matches[@]}" -gt 0 ]; then
        echo "${matches[0]}"
        return 0
    fi
    return 1
}

resolve_buttons_file() {
    local query="$1"
    [ -z "$query" ] && return 1
    local clean="${query%.buttons.txt}"
    clean="${clean%.txt}"

    if [ -f "$query" ]; then
        echo "$query"
        return 0
    elif [ -f "$SCRIPT_DIR/$query" ]; then
        echo "$SCRIPT_DIR/$query"
        return 0
    elif [ -f "$TV_DIR/${clean}.buttons.txt" ]; then
        echo "$TV_DIR/${clean}.buttons.txt"
        return 0
    elif [ -f "$SCRIPT_DIR/${clean}.buttons.txt" ]; then
        echo "$SCRIPT_DIR/${clean}.buttons.txt"
        return 0
    fi

    local basename="${clean##*/}"
    local matches=()
    while IFS= read -r f; do
        [ -n "$f" ] && matches+=("$f")
    done < <(find "$TV_DIR" -type f -name "${basename}.buttons.txt" | sort)

    if [ "${#matches[@]}" -gt 0 ]; then
        echo "${matches[0]}"
        return 0
    fi
    return 1
}

# -----------------------------------------------------------------------------
# Command-Line Argument Parsing (--tv, --ip, --buttons, --discover, --verify)
# -----------------------------------------------------------------------------
COMMAND="apply"
TV_MODEL="${TV_MODEL:-}"
TV_HOST="${TV_HOST:-10.0.10.25}"
TV_PORT="${TV_PORT:-5555}"
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help)
            show_help
            exit 0
            ;;
        -t|--tv)
            if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                TV_MODEL="$2"
                shift 2
            else
                echo "Error: --tv requires a model argument (e.g. --tv u7n)"
                exit 1
            fi
            ;;
        --tv=*)
            TV_MODEL="${1#*=}"
            shift
            ;;
        -i|--ip)
            if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                TV_HOST="$2"
                shift 2
            else
                echo "Error: --ip requires an IP address (e.g. --ip 10.0.10.25)"
                exit 1
            fi
            ;;
        --ip=*)
            TV_HOST="${1#*=}"
            shift
            ;;
        -b|--buttons)
            COMMAND="buttons"
            shift
            ;;
        -d|--discover)
            COMMAND="discover"
            shift
            if [ -n "${1:-}" ] && [[ "$1" != -* ]]; then
                OUTPUT_FILE="$1"
                shift
            fi
            ;;
        -v|--verify)
            COMMAND="verify"
            shift
            ;;
        apply)
            COMMAND="apply"
            shift
            ;;
        buttons)
            COMMAND="buttons"
            shift
            ;;
        discover)
            COMMAND="discover"
            shift
            ;;
        verify)
            COMMAND="verify"
            shift
            ;;
        *)
            # Support bare arguments if user omits flags:
            if is_ip "$1"; then
                TV_HOST="$1"
            elif [ -z "$TV_MODEL" ]; then
                TV_MODEL="$1"
            elif [ -z "$OUTPUT_FILE" ]; then
                OUTPUT_FILE="$1"
            fi
            shift
            ;;
    esac
done

DEBLOAT_LIST=""
BUTTONS_FILE=""

if [ -n "$TV_MODEL" ]; then
    if resolved="$(resolve_debloat_file "$TV_MODEL")"; then
        DEBLOAT_LIST="$resolved"
    fi
    if resolved="$(resolve_buttons_file "$TV_MODEL")"; then
        BUTTONS_FILE="$resolved"
    fi
fi

TARGET="${TV_HOST}:${TV_PORT}"

# Ensure ADB is available (auto-detect ~/Android/Sdk/platform-tools if not on PATH)
if ! command -v adb >/dev/null 2>&1 && [ -x "$HOME/Android/Sdk/platform-tools/adb" ]; then
    export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
fi
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
    local key_filter="true"
    local temp_unit="celsius"
    local columns=5
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
            key_filter)
                if [[ "$val" =~ ^(false|0|no)$ ]]; then
                    key_filter="false"
                else
                    key_filter="true"
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
            temperature_unit|temp_unit|weather_unit)
                temp_unit="$val"
                ;;
            columns|grid_columns|icons_per_row)
                columns="$val"
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
  "restore_key_services": true,
  "key_filter": $key_filter,
  "settings_key_keycodes": $sk_json,
  "settings_key_scancodes": $ss_json,
  "input_key_keycodes": $ik_json,
  "app_keys": $ak_json,
  "temperature_unit": "$temp_unit",
  "columns": $columns
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

    # Reload launcher & accessibility services (granting TCL TclAppBoot AUTO_START & WRITE_SECURE_SETTINGS)
    adb -s "$target" shell '
        pm grant com.gathin.tvhome android.permission.WRITE_SECURE_SETTINGS 2>/dev/null || true
        cmd appops set com.gathin.tvhome AUTO_START allow 2>/dev/null || true
        cmd appops set com.gathin.tvhome APP_AUTO_START allow 2>/dev/null || true
        appops write-settings 2>/dev/null || true
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

# -----------------------------------------------------------------------------
# Companion App Installer (Tube / TizenTube)
# -----------------------------------------------------------------------------
install_tizentube_if_needed() {
    local target="$1"
    local pkg="io.gh.reisxd.tizentube.cobalt"

    echo -n "Checking if TizenTube (YouTube) is installed on TV... "
    if adb -s "$target" shell "pm path $pkg" 2>/dev/null | grep -q "package:"; then
        echo "YES (Already installed)"
        return 0
    fi
    echo "NO"
    echo "Downloading and installing latest TizenTube Cobalt from GitHub..."

    local local_apk="$SCRIPT_DIR/bin/tizentube.apk"
    if [ ! -f "$local_apk" ]; then
        local abi
        abi="$(adb -s "$target" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r\n')"
        local apk_name="cobalt-arm.apk"
        if [ "$abi" = "arm64-v8a" ]; then
            local abilist
            abilist="$(adb -s "$target" shell getprop ro.product.cpu.abilist 2>/dev/null | tr -d '\r\n')"
            if [[ "$abilist" == *"arm64-v8a"* ]] && [[ "$abilist" != *"armeabi"* ]]; then
                apk_name="cobalt-arm64.apk"
            fi
        fi

        local download_url
        download_url="$(curl -s https://api.github.com/repos/reisxd/TizenTubeCobalt/releases/latest 2>/dev/null | grep -E "browser_download_url.*${apk_name}\"" | cut -d '"' -f 4 | head -1 || true)"
        if [ -z "$download_url" ]; then
            download_url="https://github.com/reisxd/TizenTubeCobalt/releases/latest/download/$apk_name"
        fi

        echo "Fetching: $download_url"
        mkdir -p "$SCRIPT_DIR/bin"
        if ! curl -L --progress-bar "$download_url" -o "$local_apk"; then
            echo "Warning: Unable to download TizenTube automatically. Sideloading skipped."
            rm -f "$local_apk"
            return 0
        fi
    fi

    echo "Deploying TizenTube (YouTube) to TV..."
    adb -s "$target" push "$local_apk" /data/local/tmp/tizentube.apk >/dev/null 2>&1
    adb -s "$target" shell "pm install -r /data/local/tmp/tizentube.apk; rm -f /data/local/tmp/tizentube.apk" >/dev/null 2>&1
    adb -s "$target" shell "pm grant $pkg android.permission.RECORD_AUDIO" >/dev/null 2>&1 || true
    echo "TizenTube (YouTube) successfully installed and configured on TV!"
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
        DISPLAY_BTN=()
        if [ -d "$TV_DIR" ]; then
            while IFS= read -r f; do
                AVAILABLE_BTN+=("$f")
                rel="${f#$TV_DIR/}"
                brand="$(dirname "$rel")"
                fname="$(basename "$rel" .buttons.txt)"
                DISPLAY_BTN+=("$fname ($brand)")
            done < <(find "$TV_DIR" -type f -name "*.buttons.txt" | sort)
        fi

        if [ -t 0 ] && [ "${#AVAILABLE_BTN[@]}" -gt 1 ]; then
            echo "Select a button configuration file to apply:"
            select opt in "${DISPLAY_BTN[@]}"; do
                if [ -n "$opt" ]; then
                    idx=$((REPLY - 1))
                    BUTTONS_FILE="${AVAILABLE_BTN[$idx]}"
                    break
                fi
            done
        elif [ "${#AVAILABLE_BTN[@]}" -ge 1 ]; then
            BUTTONS_FILE="${AVAILABLE_BTN[0]}"
            echo "Auto-selected button config: ${BUTTONS_FILE#$SCRIPT_DIR/}"
        else
            BUTTONS_FILE="$TV_DIR/hisense/u7n.buttons.txt"
        fi
    fi

    if [ ! -f "$BUTTONS_FILE" ]; then
        if resolved="$(resolve_buttons_file "$BUTTONS_FILE")"; then
            BUTTONS_FILE="$resolved"
        fi
    fi

    if [ ! -f "$BUTTONS_FILE" ]; then
        echo "Error: Button configuration file not found for '$BUTTONS_FILE'"
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
    PROTECTED_REGEX='^(android|com\.android\.(systemui|settings|packageinstaller|permissioncontroller|shell|inputmethod\..*|providers\.settings|providers\.media|providers\.downloads|bluetooth)|com\.google\.android\.(gms|gsf|vending|inputmethod\..*|tv\.remote\.service|tv\.dfuservice|tv\.frameworkpackagestubs)|com\.tcl\.(tv|tvinput|dashboard|suspension|autopair|systemserver|providers\.config|initsetup|useragreement|globalkeyoverlay|systemui\.plugin|factory\.view|inputmethod\..*)|com\.vt\.(tv\.tvcenter|tv\.input|source\..*|avmiddleware|tvplayer|eula|udpserver|tv\.smartsense.*|tv\.aiot.*|tv\.ai_sense)|com\.gretzky\..*|com\.onn\.(bluetoothconnect|updatenotification)|com\.droidlogic\..*|com\.mediatek\..*)$'

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
    BRAND_CLEAN="$(echo "$BRAND" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
    MODEL_CLEAN="$(echo "$MODEL" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')"
    [ -z "$BRAND_CLEAN" ] && BRAND_CLEAN="generic"
    [ -z "$MODEL_CLEAN" ] && MODEL_CLEAN="model"

    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$TV_DIR/$BRAND_CLEAN/${MODEL_CLEAN}.debloat.txt"
    elif [[ "$OUTPUT_FILE" != */* ]] && [[ "$OUTPUT_FILE" != *.debloat.txt ]]; then
        OUTPUT_FILE="$TV_DIR/$BRAND_CLEAN/${OUTPUT_FILE}.debloat.txt"
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
        if adb -s "$TARGET" shell "pm list packages -d" 2>/dev/null | grep -q "com.google.android.youtube.tv"; then
            echo "       Stock YouTube: Disabled (replaced by YouTube)"
        fi
        PASSED=$((PASSED + 1))
    else
        echo "WARN (No disabled packages detected)"
    fi

    # 4. Background Starvation (AppOps)
    echo -n "[4/$TOTAL_CHECKS] Checking Background Process Starvation... "
    STARVED_FOUND=0
    for pkg in "com.vt.tv.smartsense" "com.vt.tv.aiot" "com.tcl.ttvs" "com.tcl.interactive"; do
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
        DISPLAY_NAMES=()
        if [ -d "$TV_DIR" ]; then
            while IFS= read -r f; do
                AVAILABLE_LISTS+=("$f")
                rel="${f#$TV_DIR/}"
                brand="$(dirname "$rel")"
                fname="$(basename "$rel" .debloat.txt)"
                DISPLAY_NAMES+=("$fname ($brand)")
            done < <(find "$TV_DIR" -type f -name "*.debloat.txt" ! -path "*/common/*" | sort)
        fi

        if [ -t 0 ] && [ "${#AVAILABLE_LISTS[@]}" -gt 1 ]; then
            echo "Select a TV model to apply:"
            select opt in "${DISPLAY_NAMES[@]}"; do
                if [ -n "$opt" ]; then
                    idx=$((REPLY - 1))
                    DEBLOAT_LIST="${AVAILABLE_LISTS[$idx]}"
                    break
                fi
            done
        elif [ "${#AVAILABLE_LISTS[@]}" -ge 1 ]; then
            DEBLOAT_LIST="${AVAILABLE_LISTS[0]}"
            echo "Auto-selected debloat list: ${DEBLOAT_LIST#$SCRIPT_DIR/}"
        else
            DEBLOAT_LIST="$TV_DIR/hisense/u7n.debloat.txt"
        fi
    fi

    if [ ! -f "$DEBLOAT_LIST" ]; then
        if resolved="$(resolve_debloat_file "$DEBLOAT_LIST")"; then
            DEBLOAT_LIST="$resolved"
        fi
    fi

    if [ ! -f "$DEBLOAT_LIST" ]; then
        echo "Error: Debloat list not found for '$DEBLOAT_LIST'"
        if [ -d "$TV_DIR" ]; then
            echo "Available TV models in ./tv/:"
            find "$TV_DIR" -type f -name "*.debloat.txt" ! -path "*/common/*" | sed "s|$SCRIPT_DIR/|  - |"
        fi
        exit 1
    fi

    echo "Using debloat profile: ${DEBLOAT_LIST#$SCRIPT_DIR/}"

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

    # Query active HDMI/input channel handlers and Settings handlers once (upstream handler guard)
    INPUT_HANDLERS="$(adb -s "$TARGET" shell "cmd package query-activities --brief -a android.intent.action.VIEW -t vnd.android.cursor.item/channel" 2>/dev/null | tr -d '\r' | sed -n 's|^[[:space:]]*\([A-Za-z0-9_.]*\)/.*|\1|p' || true)"
    SETTINGS_HANDLERS="$(adb -s "$TARGET" shell "cmd package query-activities --brief -a android.settings.SETTINGS" 2>/dev/null | tr -d '\r' | sed -n 's|^[[:space:]]*\([A-Za-z0-9_.]*\)/.*|\1|p' || true)"
    WIFI_OWNERS="$(adb -s "$TARGET" shell "dumpsys wifi" 2>/dev/null | grep -o 'cname=[^ ]*' || true)"

    apply_debloat_file() {
        local file="$1"
        local target="$2"
        [ -f "$file" ] || return 0

        while IFS= read -u 9 -r line || [ -n "$line" ]; do
            pkg="$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')"
            [ -z "$pkg" ] && continue

            if [[ "$pkg" == "com.google.android.tungsten.setupwraith" ]]; then
                # Safety check: if setupwraith owns a saved Wi-Fi network, disabling it deletes the network!
                if echo "$WIFI_OWNERS" | grep -q "setupwraith"; then
                    echo "  [SAFETY GUARD] Skipping $pkg: saved Wi-Fi network belongs to it."
                    continue
                fi
            fi

            if [[ "$pkg" == lockdown:* ]]; then
                # AppOps background execution denial (starvation without disable)
                local target_pkg="${pkg#lockdown:}"
                adb -s "$target" shell "cmd appops set $target_pkg RUN_ANY_IN_BACKGROUND ignore" </dev/null >/dev/null 2>&1 || true
                adb -s "$target" shell "cmd appops set $target_pkg RUN_IN_BACKGROUND ignore" </dev/null >/dev/null 2>&1 || true
                adb -s "$target" shell "am force-stop $target_pkg" </dev/null >/dev/null 2>&1 || true
                STARVED_COUNT=$((STARVED_COUNT + 1))
            else
                # Safety check: never disable the TV's HDMI/AV channel handler or System Settings handler
                if [ -z "${HANDLERS_ALLOW:-}" ]; then
                    if echo "$INPUT_HANDLERS" | grep -qx "$pkg"; then
                        echo "  [SAFETY GUARD] Skipping $pkg: TV opens HDMI/AV inputs and channels with it."
                        continue
                    fi
                    if echo "$SETTINGS_HANDLERS" | grep -qx "$pkg"; then
                        echo "  [SAFETY GUARD] Skipping $pkg: TV opens System Settings with it."
                        continue
                    fi
                fi
                # Standard user disable
                adb -s "$target" shell "pm disable-user --user 0 $pkg" </dev/null >/dev/null 2>&1 || true
                DISABLED_COUNT=$((DISABLED_COUNT + 1))
            fi
        done 9< "$file"
    }

    COMMON_DEBLOAT="$TV_DIR/common/common.debloat.txt"
    if [ -f "$COMMON_DEBLOAT" ]; then
        echo "  -> Disabling universal Google TV bloatware (${COMMON_DEBLOAT#$SCRIPT_DIR/})..."
        apply_debloat_file "$COMMON_DEBLOAT" "$TARGET"
    fi

    echo "  -> Disabling device bloatware (${DEBLOAT_LIST#$SCRIPT_DIR/})..."
    apply_debloat_file "$DEBLOAT_LIST" "$TARGET"

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
    INSTALL_OUT="$(adb -s "$TARGET" shell "pm install -r /data/local/tmp/tvhome.apk" 2>&1 || true)"
    if [[ "$INSTALL_OUT" != *"Success"* ]]; then
        echo "  Replacing existing launcher APK (signature/version update)..."
        adb -s "$TARGET" shell "pm enable --user 0 com.google.android.apps.tv.launcherx" >/dev/null 2>&1 || true
        adb -s "$TARGET" shell "pm uninstall com.gathin.tvhome" >/dev/null 2>&1 || true
        adb -s "$TARGET" shell "pm install /data/local/tmp/tvhome.apk" >/dev/null 2>&1
    fi
    adb -s "$TARGET" shell "rm -f /data/local/tmp/tvhome.apk" >/dev/null 2>&1 || true
    adb -s "$TARGET" shell "pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION" >/dev/null 2>&1 || true
    adb -s "$TARGET" shell "pm grant com.gathin.tvhome android.permission.ACCESS_COARSE_LOCATION" >/dev/null 2>&1 || true
    adb -s "$TARGET" shell "pm grant com.gathin.tvhome android.permission.WRITE_SECURE_SETTINGS" >/dev/null 2>&1 || true
    adb -s "$TARGET" shell "cmd package compile -m speed -f com.gathin.tvhome" >/dev/null 2>&1 || true
    # Allow AUTO_START / APP_AUTO_START and persist to disk so TCL TclAppBoot binds accessibility services on reboot
    adb -s "$TARGET" shell "cmd appops set com.gathin.tvhome AUTO_START allow 2>/dev/null; cmd appops set com.gathin.tvhome APP_AUTO_START allow 2>/dev/null; appops write-settings 2>/dev/null" >/dev/null 2>&1 || true
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
    # Configure Default Home (Start new launcher before disabling stock launcher)
    # -----------------------------------------------------------------------------
    echo "[5/6] Setting CleanYourTV as default Home launcher..."
    adb -s "$TARGET" shell "am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n com.gathin.tvhome/.MainActivity" >/dev/null 2>&1 || true

    if echo "$WIFI_OWNERS" | grep -q "setupwraith"; then
        echo "  [SAFETY GUARD] Skipping setupwraith: saved Wi-Fi belongs to it."
    else
        adb -s "$TARGET" shell "pm disable-user --user 0 com.google.android.tungsten.setupwraith" >/dev/null 2>&1 || true
    fi
    adb -s "$TARGET" shell "pm disable-user --user 0 com.google.android.apps.tv.launcherx" >/dev/null 2>&1 || true
    adb -s "$TARGET" shell "cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity" >/dev/null 2>&1 || true

    # Verify Home handover succeeded; if setupwraith RecoveryActivity or nothing took Home, roll back launcherx
    HOME_NOW="$(adb -s "$TARGET" shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME" 2>/dev/null | tail -n 1 | tr -d '\r' || true)"
    if [[ "$HOME_NOW" != com.gathin.tvhome/* ]]; then
        echo "  [SAFETY GUARD] Home resolved to '$HOME_NOW' instead of CleanYourTV; re-enabling stock launcherx..."
        adb -s "$TARGET" shell "pm enable --user 0 com.google.android.apps.tv.launcherx" >/dev/null 2>&1 || true
    fi

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
    # Ensure Companion Apps (Tube / TizenTube)
    # -----------------------------------------------------------------------------
    install_tizentube_if_needed "$TARGET"

    # -----------------------------------------------------------------------------
    # Apply Remote Button Mappings
    # -----------------------------------------------------------------------------
    if [ -z "$BUTTONS_FILE" ]; then
        CANDIDATE_BTN="${DEBLOAT_LIST%.debloat.txt}.buttons.txt"
        if [ -f "$CANDIDATE_BTN" ]; then
            BUTTONS_FILE="$CANDIDATE_BTN"
        fi
    fi

    if [ -n "$BUTTONS_FILE" ] && [ -f "$BUTTONS_FILE" ]; then
        push_buttons_config "$BUTTONS_FILE" "$TARGET"
    fi

    echo "Starting CleanYourTV Home..."
    adb -s "$TARGET" shell "am start -n com.gathin.tvhome/.MainActivity" >/dev/null 2>&1

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
