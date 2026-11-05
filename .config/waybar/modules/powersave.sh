#!/usr/bin/env bash
# Ultimate Power Saver Mode Manager
# Optimized for battery life and quiet study at school:
# - Lowers CPU EPP and platform profile via power-profiles-daemon (power-saver)
# - Switches display refresh rate to 60Hz (saves ~2-4W on high refresh panels)
# - Caps brightness if high (saves ~2W) and remembers user's previous brightness
# - Disables Bluetooth if idle
# - Notifies user and signals Waybar for instantaneous UI update

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/powersave_mode"
PREV_BRIGHTNESS_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/powersave_prev_brightness"
mkdir -p "$(dirname "$STATE_FILE")"

is_active() {
    if [ -f "$STATE_FILE" ]; then
        grep -q "ON" "$STATE_FILE" 2>/dev/null
        return $?
    fi
    if command -v powerprofilesctl >/dev/null 2>&1; then
        [ "$(powerprofilesctl get 2>/dev/null)" = "power-saver" ]
        return $?
    fi
    return 1
}

enable_powersave() {
    # 1. Set CPU and Lenovo platform power profile to power-saver
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set power-saver 2>/dev/null || true
    fi

    # 2. Switch eDP-1 display refresh rate from 165Hz to 60Hz
    if command -v wlr-randr >/dev/null 2>&1; then
        wlr-randr --output eDP-1 --mode 2560x1600@60.000000Hz 2>/dev/null || true
    fi

    # 3. Brightness optimization: save current and cap to 35% if higher
    if command -v brightnessctl >/dev/null 2>&1; then
        local curr_bright
        curr_bright=$(brightnessctl -d nvidia_0 get 2>/dev/null || brightnessctl get 2>/dev/null)
        local max_bright
        max_bright=$(brightnessctl -d nvidia_0 max 2>/dev/null || brightnessctl max 2>/dev/null)
        if [ -n "$curr_bright" ] && [ -n "$max_bright" ] && [ "$max_bright" -gt 0 ]; then
            local pct=$(( curr_bright * 100 / max_bright ))
            echo "$curr_bright" > "$PREV_BRIGHTNESS_FILE"
            if [ "$pct" -gt 40 ]; then
                brightnessctl -d nvidia_0 set 35% 2>/dev/null || brightnessctl set 35% 2>/dev/null || true
            fi
        fi
    fi

    # 4. Turn off bluetooth if enabled
    if command -v rfkill >/dev/null 2>&1; then
        rfkill block bluetooth 2>/dev/null || true
    fi

    # 5. Save state
    echo "ON" > "$STATE_FILE"

    # 6. Notify and signal Waybar
    notify-send -a "Power Manager" -i battery-low "Ultimate Power Saver ON" "• CPU: Power Saver (Low Power)\n• Screen: 60Hz (Reduced scanout power)\n• Brightness: Optimized for Study" 2>/dev/null || true
    pkill -RTMIN+10 waybar 2>/dev/null || true
}

disable_powersave() {
    # 1. Restore balanced CPU and platform power profile
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set balanced 2>/dev/null || true
    fi

    # 2. Restore 165Hz display refresh rate
    if command -v wlr-randr >/dev/null 2>&1; then
        wlr-randr --output eDP-1 --mode 2560x1600@165.001007Hz 2>/dev/null || true
    fi

    # 3. Restore previous brightness if saved
    if [ -f "$PREV_BRIGHTNESS_FILE" ] && command -v brightnessctl >/dev/null 2>&1; then
        local prev_val
        prev_val=$(cat "$PREV_BRIGHTNESS_FILE" 2>/dev/null)
        if [ -n "$prev_val" ]; then
            brightnessctl -d nvidia_0 set "$prev_val" 2>/dev/null || brightnessctl set "$prev_val" 2>/dev/null || true
        fi
    fi

    # 4. Save state
    echo "OFF" > "$STATE_FILE"

    # 5. Notify and signal Waybar
    notify-send -a "Power Manager" -i battery-good "Ultimate Power Saver OFF" "• CPU: Balanced Performance\n• Screen: 165Hz Fluid Refresh\n• Brightness: Restored" 2>/dev/null || true
    pkill -RTMIN+10 waybar 2>/dev/null || true
}

toggle_mode() {
    if is_active; then
        disable_powersave
    else
        enable_powersave
    fi
}

show_menu() {
    local opt_eco="󰌪  Ultimate Power Saver (60Hz • Low Power • Study)"
    local opt_std="󱐋  Balanced Performance  (165Hz • Full Speed • Standard)"

    if is_active; then
        opt_eco="$opt_eco  [Active]"
    else
        opt_std="$opt_std  [Active]"
    fi

    local options="$opt_eco\n$opt_std"
    local selected
    selected=$(printf "%b" "$options" | rofi -dmenu -i -p "Power Profile")

    [ -z "$selected" ] && exit 0

    case "$selected" in
        *"Ultimate Power Saver"*)
            enable_powersave
            ;;
        *"Balanced Performance"*)
            disable_powersave
            ;;
    esac
}

print_status() {
    if is_active; then
        printf '{"text": "󰌪 ECO", "alt": "active", "tooltip": "Ultimate Power Saver Mode: ACTIVE\\n• Profile: Low Power & EPP Power\\n• Screen: 60Hz\\n• Study Mode: Maximum battery runtime\\n• Left-click: Turn OFF\\n• Right-click: Menu", "class": "active"}\n'
    else
        printf '{"text": "󱐋 STD", "alt": "inactive", "tooltip": "Power Mode: Balanced\\n• Profile: Balanced\\n• Screen: 165Hz Fluid\\n• Left-click: Turn ON Ultimate Power Saver\\n• Right-click: Menu", "class": "inactive"}\n'
    fi
}

case "$1" in
    "status")
        print_status
        ;;
    "toggle")
        toggle_mode
        ;;
    "on")
        enable_powersave
        ;;
    "off")
        disable_powersave
        ;;
    "menu")
        show_menu
        ;;
    *)
        toggle_mode
        ;;
esac
