#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo ./install.sh"
    exit 1
fi

echo "Installing HP OmniBook X Flip 16 mute LED service..."

# Check dependencies
for cmd in hda-verb amixer alsactl evtest; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        echo "Missing dependency: $cmd"
        echo "Install with: sudo dnf install alsa-tools alsa-utils evtest"
        exit 1
    fi
done

# Install script, service, and sleep hook
install -m 755 hp-mute-leds.sh /usr/local/bin/hp-mute-leds.sh
install -m 644 hp-mute-leds.service /etc/systemd/system/hp-mute-leds.service
install -m 755 hp-mute-leds-resume.sh /usr/lib/systemd/system-sleep/hp-mute-leds-resume.sh

systemctl daemon-reload
systemctl enable --now hp-mute-leds.service

echo "Done! Service is running and will start on boot."
echo "Check status: systemctl status hp-mute-leds.service"
