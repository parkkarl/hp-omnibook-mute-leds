# HP OmniBook X Flip 16 Mute LED Fix for Linux

Fixes the non-functional volume mute (F6) and mic mute (F9) keyboard LED indicators on the **HP OmniBook X Flip Laptop 16-as0xxx** running Linux.

## Problem

The mute keys work correctly (audio/mic gets muted), but the LED indicators on the keyboard don't light up to reflect the mute state. This happens because the Linux kernel's Realtek HDA driver is missing a quirk entry for this laptop's subsystem ID (`0x103c8da1`).

## How It Works

This is a userspace workaround that controls the LEDs via the HDA codec's registers:

- **Volume mute LED**: Controlled via processing coefficient register `0x0b`, bit 3
- **Mic mute LED**: Controlled via GPIO pin 2 with inverted polarity

The script runs as a systemd service that:
1. Monitors ALSA mixer events for volume mute changes
2. Monitors HP WMI hotkey input events for mic mute (KEY_MICMUTE) presses
3. Toggles the corresponding LED via `hda-verb` commands

## Supported Hardware

| Field | Value |
|-------|-------|
| Laptop | HP OmniBook X Flip Laptop 16-as0xxx |
| Codec | Realtek ALC245 |
| Subsystem ID | `0x103c8da1` |
| Audio driver | SOF (sof-audio-pci-intel-lnl) |

## Dependencies

- `hda-verb` (from `alsa-tools`)
- `amixer`, `alsactl` (from `alsa-utils`)
- `evtest`

### Fedora / RHEL

```bash
sudo dnf install alsa-tools alsa-utils evtest
```

### Ubuntu / Debian

```bash
sudo apt install alsa-tools alsa-utils evtest
```

### Arch Linux

```bash
sudo pacman -S alsa-tools alsa-utils evtest
```

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/hp-omnibook-mute-leds.git
cd hp-omnibook-mute-leds
sudo ./install.sh
```

## Uninstallation

```bash
cd hp-omnibook-mute-leds
sudo ./uninstall.sh
```

## Verifying

```bash
# Check service status
systemctl status hp-mute-leds.service

# Test manually
sudo hda-verb /dev/snd/hwC0D0 0x20 0x500 0x0b   # select COEF 0x0b
sudo hda-verb /dev/snd/hwC0D0 0x20 0x400 0x7778  # volume mute LED ON
sudo hda-verb /dev/snd/hwC0D0 0x20 0x400 0x7770  # volume mute LED OFF
```

## Technical Details

The Realtek ALC245 codec on this HP laptop controls LEDs through two mechanisms:

### Volume Mute LED (COEF Register)
- Register: Processing Coefficient index `0x0b`
- Base value: `0x7770`
- LED ON: Set bit 3 → `0x7778`
- LED OFF: Clear bit 3 → `0x7770`
- Access: Write index via verb `0x500`, read/write data via verbs `0xc00`/`0x400` on NID `0x20`

### Mic Mute LED (GPIO)
- Pin: GPIO 2 (`0x04`)
- Polarity: Inverted (LOW = LED ON, HIGH = LED OFF)
- Setup: Enable via GPIO mask (`0x716`), set direction to output (`0x717`), control via GPIO data (`0x715`) on NID `0x01`

### Why This Happens
The kernel's `snd_hda_codec_alc269` driver applies fixups based on the PCI subsystem ID. The ID `0x103c8da1` is not yet in the fixup table, so the mute LED quirk (`ALC245_FIXUP_HP_MUTE_LED_V1_COEFBIT` or similar) is never applied. Additionally, this laptop uses the SOF audio driver path, which makes the `snd-hda-intel` `patch=` and `model=` workarounds ineffective.

### Upstream Kernel Fix
The proper long-term fix is adding a `SND_PCI_QUIRK` entry to `sound/pci/hda/patch_realtek.c`:

```c
SND_PCI_QUIRK(0x103c, 0x8da1, "HP OmniBook X Flip 16", ALC245_FIXUP_HP_MUTE_LED_COEFBIT),
```

If you want to help, submit a patch to `alsa-devel@alsa-project.org` or file a bug at https://bugzilla.kernel.org/ (Product: Drivers, Component: Sound(ALSA)).

## License

MIT
