#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo ./uninstall.sh"
    exit 1
fi

echo "Removing HP OmniBook X Flip 16 mute LED service..."

systemctl stop hp-mute-leds.service 2>/dev/null || true
systemctl disable hp-mute-leds.service 2>/dev/null || true
rm -f /etc/systemd/system/hp-mute-leds.service
rm -f /usr/local/bin/hp-mute-leds.sh
rm -f /usr/lib/systemd/system-sleep/hp-mute-leds-resume.sh
rm -f /run/hp-mute-leds-mic-state
systemctl daemon-reload

echo "Done! Service removed."
