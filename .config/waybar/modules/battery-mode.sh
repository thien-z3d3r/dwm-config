#!/usr/bin/env bash
# Script to manage Lenovo battery charging modes:
# - Conservation (Long_Life: stop charging at 80% and use adapter power)
# - Normal Charging (Standard: normal charge to 100%)
# - Rapid Charging (Fast: ultra fast charging to 100%)

BAT_SYSFS="/sys/class/power_supply/BAT0/charge_types"

# Fallback auto-detection if BAT0 is not the only battery
if [ ! -f "$BAT_SYSFS" ]; then
    for f in /sys/class/power_supply/BAT*/charge_types; do
        if [ -f "$f" ]; then
            BAT_SYSFS="$f"
            break
        fi
    done
fi

get_active_raw() {
    if [ ! -f "$BAT_SYSFS" ]; then
        echo "Unknown"
        return
    fi
    grep -o '\[[a-zA-Z0-9_]*\]' "$BAT_SYSFS" 2>/dev/null | tr -d '[]'
}

apply_mode() {
    local target="$1"
    local mode_name="$2"
    local mode_desc="$3"
    local icon="$4"

    if [ ! -f "$BAT_SYSFS" ]; then
        notify-send -u critical -a "Battery Mode" "Error" "Battery charge_types sysfs interface not found!"
        return 1
    fi

    local success=0
    if [ -w "$BAT_SYSFS" ]; then
        if printf "%s" "$target" > "$BAT_SYSFS" 2>/dev/null; then
            success=1
        fi
    fi

    if [ $success -ne 1 ]; then
        if command -v pkexec >/dev/null 2>&1; then
            if pkexec sh -c "printf '%s' '$target' > '$BAT_SYSFS'"; then
                success=1
            fi
        elif command -v sudo >/dev/null 2>&1; then
            if sudo -n sh -c "printf '%s' '$target' > '$BAT_SYSFS'" 2>/dev/null; then
                success=1
            fi
        fi
    fi

    if [ $success -eq 1 ]; then
        notify-send -a "Waybar" -i battery-charging "Battery Charging Mode" "$icon $mode_name\n$mode_desc"
        pkill -RTMIN+9 waybar 2>/dev/null || true
    else
        notify-send -u critical -a "Waybar" "Permission Denied" "Could not write to $BAT_SYSFS.\nPlease run the one-time permissions setup."
        return 1
    fi
}

set_mode() {
    case "$1" in
        "conservation"|"Long_Life")
            apply_mode "Long_Life" "Conservation Mode" "Capped at 80%, using adapter power directly" "󰚥"
            ;;
        "normal"|"Standard")
            apply_mode "Standard" "Normal Charging" "Standard charging up to 100%" "󰂄"
            ;;
        "rapid"|"Fast")
            apply_mode "Fast" "Rapid Charging" "Ultra fast charging up to 100%" "󱐋"
            ;;
        *)
            echo "Usage: $0 set [conservation|normal|rapid]"
            exit 1
            ;;
    esac
}

cycle_next() {
    local active
    active=$(get_active_raw)
    case "$active" in
        "Long_Life")
            set_mode "normal"
            ;;
        "Standard")
            set_mode "rapid"
            ;;
        "Fast")
            set_mode "conservation"
            ;;
        *)
            set_mode "conservation"
            ;;
    esac
}

cycle_prev() {
    local active
    active=$(get_active_raw)
    case "$active" in
        "Long_Life")
            set_mode "rapid"
            ;;
        "Fast")
            set_mode "normal"
            ;;
        "Standard")
            set_mode "conservation"
            ;;
        *)
            set_mode "conservation"
            ;;
    esac
}

show_menu() {
    local active
    active=$(get_active_raw)

    local mark_cons=""
    local mark_norm=""
    local mark_fast=""

    case "$active" in
        "Long_Life") mark_cons="  [Active]" ;;
        "Standard")  mark_norm="  [Active]" ;;
        "Fast")      mark_fast="  [Active]" ;;
    esac

    local opt_cons="󰚥  Conservation  (80% limit • adapter bypass)$mark_cons"
    local opt_norm="󰂄  Normal Charge (Standard 100%)$mark_norm"
    local opt_fast="󱐋  Rapid Charge  (Fast 100%)$mark_fast"

    local options="$opt_cons\n$opt_norm\n$opt_fast"
    local selected
    selected=$(printf "%b" "$options" | rofi -dmenu -i -p "Charging Mode")

    [ -z "$selected" ] && exit 0

    case "$selected" in
        *"Conservation"*)
            set_mode "conservation"
            ;;
        *"Normal Charge"*)
            set_mode "normal"
            ;;
        *"Rapid Charge"*)
            set_mode "rapid"
            ;;
    esac
}

print_status() {
    local active
    active=$(get_active_raw)

    case "$active" in
        "Long_Life")
            printf '{"text": "󰚥", "alt": "conservation", "tooltip": "Charging Mode: Conservation\\n• Limit: 80%%\\n• Power: AC Adapter directly\\n• Left-click: Select mode\\n• Right-click: Cycle mode", "class": "conservation"}\n'
            ;;
        "Standard")
            printf '{"text": "󰂄", "alt": "normal", "tooltip": "Charging Mode: Normal Charging\\n• Limit: 100%%\\n• Rate: Standard\\n• Left-click: Select mode\\n• Right-click: Cycle mode", "class": "normal"}\n'
            ;;
        "Fast")
            printf '{"text": "󱐋", "alt": "rapid", "tooltip": "Charging Mode: Rapid Charging\\n• Limit: 100%%\\n• Rate: Ultra fast\\n• Left-click: Select mode\\n• Right-click: Cycle mode", "class": "rapid"}\n'
            ;;
        *)
            printf '{"text": "󰚥", "alt": "unknown", "tooltip": "Charging Mode: Unknown (%s)", "class": "unknown"}\n' "$active"
            ;;
    esac
}

case "$1" in
    "status")
        print_status
        ;;
    "menu")
        show_menu
        ;;
    "next"|"cycle")
        cycle_next
        ;;
    "prev")
        cycle_prev
        ;;
    "set")
        set_mode "$2"
        ;;
    "get")
        get_active_raw
        ;;
    *)
        show_menu
        ;;
esac
