#!/usr/bin/env bash
# One-time setup script to grant permissions for switching battery charging modes without password.
# Run with sudo: sudo ~/.config/waybar/modules/setup-battery-permissions.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "This setup script requires root privileges."
    echo "Running with sudo..."
    exec sudo bash "$0" "$@"
fi

echo "Setting up udev rule for battery charge_types..."
cat << 'EOF' > /etc/udev/rules.d/99-battery-charge-types.rules
ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT*", RUN+="/bin/chmod 0666 /sys/class/power_supply/%k/charge_types"
EOF

echo "Setting up systemd tmpfiles rule for battery charge_types..."
cat << 'EOF' > /etc/tmpfiles.d/battery-charge-types.conf
z /sys/class/power_supply/BAT*/charge_types 0666 root root -
EOF

echo "Applying permissions immediately..."
chmod 0666 /sys/class/power_supply/BAT*/charge_types 2>/dev/null || true
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger --subsystem-match=power_supply 2>/dev/null || true

echo "✓ Permissions setup complete! Battery charging modes can now be changed without root prompts."
