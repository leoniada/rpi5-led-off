# rpi5-led-off

Turn off the status LEDs on a Raspberry Pi 5 - both the green ACT and red PWR, with a systemd service that runs automatically after boot.

> **Note:** LEDs turn off 90 seconds after boot. This delay is intentional - the RP1 (Raspberry Pi's custom I/O chip, new in Pi 5) and the kernel LED subsystem need time to fully initialise. If you reboot and the LEDs are still on, just wait.

## Why is this needed?

On Raspberry Pi 3/4, turning off LEDs is straightforward:

```bash
echo none | sudo tee /sys/class/leds/ACT/trigger
echo 0    | sudo tee /sys/class/leds/ACT/brightness
```

**On Raspberry Pi 5, this does nothing.** The Pi 5 uses the RP1 south bridge chip, and the LEDs are wired to GPIOs on two separate controllers — outside the standard kernel LED subsystem. The sysfs paths exist but don't reach the hardware.

On top of that, the `leds-gpio` kernel driver on Pi 5 has a side-effect bug: writing to `PWR/brightness` resets GPIO44 (the red LED's pin), and calling `pinctrl set 44` resets `PWR/brightness` back to 255. This circular dependency makes the naive approach impossible.

This script works around all of it.

---

## GPIO mapping (Pi 5)

Discovered via `sudo pinctrl | grep LED` and `/sys/kernel/debug/gpio`:

| GPIO | Chip | Kernel name | Physical LED | Logic |
|------|------|-------------|--------------|-------|
| GPIO44 | RP1 | `RP1_STAT_LED` | Red (PWR) | `dh` = OFF, `dl` = ON |
| GPIO209 | BCM2712 AON | `2712_STAT_LED` | Green (ACT) | `dl` = OFF, `dh` = ON |

> Note: the kernel's leds subsystem labels them with swapped names (`ACT`/`PWR`), which is the opposite of the physical LED colors. Don't trust the names - trust the GPIO numbers.

The solution is to **bypass the leds-gpio driver entirely** and control both GPIOs directly with `pinctrl`, after disabling the kernel triggers that would otherwise fight back.

---

## Requirements

- Raspberry Pi 5
- Raspberry Pi OS (or any Debian-based distro for Pi 5)
- `pinctrl` — included in `raspi-utils`, installed by default

---

## Installation

```bash
git clone https://github.com/leoniada/rpi5-led-off
cd rpi5-led-off
sudo bash install.sh
```

This will:
1. Copy `led5off.sh` to `/usr/local/bin/`
2. Install `led5off.service` and `led5off.timer` to `/etc/systemd/system/`
3. Enable and start the timer (LEDs will turn off 3 minutes after every boot)

---

## Usage

```bash
# Turn LEDs off
sudo led5off.sh -off

# Turn LEDs back on
sudo led5off.sh -on

# Help
led5off.sh
```

### Systemd

```bash
# Check timer status
sudo systemctl status led5off.timer

# Check last service run
sudo systemctl status led5off.service

# Trigger immediately (without waiting for the timer)
sudo systemctl start led5off.service

# Disable autostart
sudo systemctl disable led5off.timer
```

---

## How it works

### Why `pinctrl` instead of sysfs

The standard `/sys/class/leds/` interface doesn't control the physical hardware on Pi 5. `pinctrl` is Pi's low-level GPIO tool that writes directly to hardware registers, bypassing the kernel driver.

### Why disable kernel triggers first

Even after using `pinctrl`, the `leds-gpio` driver holds references to both GPIOs and will periodically reassert its state (especially via the `mmc0` trigger on the ACT LED, which blinks on disk activity). The script disables these triggers first:

```bash
echo none > /sys/devices/platform/leds/leds/ACT/trigger
echo none > /sys/devices/platform/soc@107c000000/1000fff000.mmc/leds/mmc0::/trigger
```

### Why not write to `PWR/brightness`

Writing `0` to `/sys/devices/platform/leds/leds/PWR/brightness` disables the red LED but simultaneously drives GPIO44 high via the `leds-gpio` driver internals. Then when `pinctrl set 44 op dh` is called to fix that, it resets `PWR/brightness` back to 255. The two operations fight each other in a loop.

The workaround: skip `PWR/brightness` entirely and control both LEDs exclusively through `pinctrl`.

### Why a 3-minute delay

On fresh boot, the kernel LED subsystem and RP1 firmware initialise asynchronously. Running the script too early can have its changes overwritten. A 3-minute `OnBootSec` timer (via systemd) is enough for everything to settle.

---

## Files

```
led5off.sh           — main script (-off / -on)
led5off.service      — systemd oneshot service
led5off.timer        — systemd timer (OnBootSec=3min)
install.sh           — installer
```

---

## Diagnostics

```bash
# Inspect current GPIO states
sudo pinctrl | grep LED

# Read kernel GPIO debug (shows physical state + active_low flag)
sudo cat /sys/kernel/debug/gpio | grep -i "act\|pwr\|stat"

# Read mmc0:: trigger state
cat /sys/devices/platform/soc@107c000000/1000fff000.mmc/leds/mmc0::/trigger
```

---

## Tested on

- Raspberry Pi 5 (4 GB)
- Raspberry Pi OS Bookworm (64-bit), kernel 6.12

---

## License

MIT
