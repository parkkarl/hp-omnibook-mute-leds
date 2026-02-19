#!/bin/bash
# HP OmniBook X Flip 16 (ALC245, subsystem 0x103c8da1) mute LED sync
#
# Volume mute LED: HDA COEF 0x0b, bit 3
#   ON  = 0x7778 (base 0x7770 | 0x08)
#   OFF = 0x7770 (base 0x7770)
#
# Mic mute LED: HDA GPIO 2, inverted polarity
#   ON  = GPIO 2 LOW  (data & ~0x04)
#   OFF = GPIO 2 HIGH (data | 0x04)

set -euo pipefail

# Auto-detect HDA codec device (ALC245)
find_codec() {
    for dev in /dev/snd/hwC*D*; do
        if [ -f "/proc/asound/card${dev##*hwC}" ] 2>/dev/null; then
            continue
        fi
        local card="${dev#/dev/snd/hwC}"
        card="${card%%D*}"
        local addr="${dev##*D}"
        local codec_file="/proc/asound/card${card}/codec#${addr}"
        if [ -f "$codec_file" ] && grep -q "ALC245" "$codec_file" 2>/dev/null; then
            echo "$dev"
            return 0
        fi
    done
    return 1
}

# Auto-detect HP WMI hotkeys input device
find_wmi_device() {
    for dev in /dev/input/event*; do
        local name
        name=$(cat "/sys/class/input/${dev##*/}/device/name" 2>/dev/null || true)
        if [ "$name" = "HP WMI hotkeys" ]; then
            echo "$dev"
            return 0
        fi
    done
    return 1
}

CODEC=$(find_codec) || { echo "ERROR: ALC245 codec not found"; exit 1; }
WMI_DEVICE=$(find_wmi_device) || { echo "ERROR: HP WMI hotkeys device not found"; exit 1; }
MIC_STATE_FILE="/run/hp-mute-leds-mic-state"

echo "Using codec: $CODEC"
echo "Using WMI device: $WMI_DEVICE"

# Initialize GPIO 2: enable as output, set high (mic mute LED off)
hda-verb "$CODEC" 0x01 0x716 0x04 > /dev/null 2>&1  # GPIO mask
hda-verb "$CODEC" 0x01 0x717 0x04 > /dev/null 2>&1  # GPIO direction
hda-verb "$CODEC" 0x01 0x715 0x04 > /dev/null 2>&1  # GPIO data (high = LED off)

set_volume_mute_led() {
    hda-verb "$CODEC" 0x20 0x500 0x0b > /dev/null 2>&1
    if [ "$1" -eq 1 ]; then
        hda-verb "$CODEC" 0x20 0x400 0x7778 > /dev/null 2>&1
    else
        hda-verb "$CODEC" 0x20 0x400 0x7770 > /dev/null 2>&1
    fi
}

set_mic_mute_led() {
    if [ "$1" -eq 1 ]; then
        hda-verb "$CODEC" 0x01 0x715 0x00 > /dev/null 2>&1
    else
        hda-verb "$CODEC" 0x01 0x715 0x04 > /dev/null 2>&1
    fi
}

get_volume_mute() {
    amixer -c 0 get Master 2>/dev/null | grep -c '\[off\]'
}

# Mic is unmuted at boot; F9 toggles state
echo 0 > "$MIC_STATE_FILE"
set_mic_mute_led 0

# Set initial volume LED state
if [ "$(get_volume_mute)" -gt 0 ]; then
    set_volume_mute_led 1
else
    set_volume_mute_led 0
fi

echo "LEDs initialized. Monitoring..."

# Monitor volume mute via ALSA events
monitor_volume() {
    local prev_vol_mute
    prev_vol_mute=$(get_volume_mute)
    stdbuf -oL alsactl monitor 2>/dev/null | while read -r _; do
        vol_mute=$(get_volume_mute)
        if [ "$vol_mute" != "$prev_vol_mute" ]; then
            if [ "$vol_mute" -gt 0 ]; then
                set_volume_mute_led 1
            else
                set_volume_mute_led 0
            fi
            prev_vol_mute=$vol_mute
        fi
    done
}

# Monitor mic mute via KEY_MICMUTE input events from HP WMI
monitor_micmute() {
    stdbuf -oL evtest "$WMI_DEVICE" 2>/dev/null | while read -r line; do
        if echo "$line" | grep -q "code 248 (KEY_MICMUTE), value 1"; then
            mic_state=$(cat "$MIC_STATE_FILE")
            if [ "$mic_state" -eq 0 ]; then
                echo 1 > "$MIC_STATE_FILE"
                set_mic_mute_led 1
            else
                echo 0 > "$MIC_STATE_FILE"
                set_mic_mute_led 0
            fi
        fi
    done
}

cleanup() {
    rm -f "$MIC_STATE_FILE"
    hda-verb "$CODEC" 0x20 0x500 0x0b > /dev/null 2>&1
    hda-verb "$CODEC" 0x20 0x400 0x7770 > /dev/null 2>&1
    hda-verb "$CODEC" 0x01 0x715 0x04 > /dev/null 2>&1
    kill $(jobs -p) 2>/dev/null
}
trap cleanup EXIT

monitor_volume &
monitor_micmute &

wait
