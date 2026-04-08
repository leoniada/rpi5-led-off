#!/bin/bash

# led5off.sh — turn off status LEDs on Raspberry Pi 5
# Usage: led5off.sh -off | -on
#
# GPIO mapping:
#   GPIO44  (RP1_STAT_LED,  kernel name: PWR) = red  LED — dh=OFF, dl=ON
#   GPIO209 (2712_STAT_LED, kernel name: ACT) = green LED — dl=OFF, dh=ON
#
# Note: kernel leds-gpio driver has a side-effect bug on Pi5 — writing to
# PWR/brightness resets GPIO44, and pinctrl set 44 resets PWR/brightness.
# Solution: skip sysfs brightness entirely, use pinctrl only.

run() {
    if [ "$(id -u)" = "0" ]; then
        "$@"
    else
        sudo "$@"
    fi
}

tee_write() {
    if [ "$(id -u)" = "0" ]; then
        echo "$1" > "$2"
    else
        echo "$1" | sudo tee "$2" > /dev/null
    fi
}

led_off() {
    # Disable kernel triggers so the leds-gpio driver stops fighting pinctrl
    tee_write none /sys/devices/platform/leds/leds/ACT/trigger
    tee_write none /sys/devices/platform/soc@107c000000/1000fff000.mmc/leds/mmc0::/trigger

    # Red LED off: GPIO44 → drive high (active_low: hi = off)
    run pinctrl set 44 op dh

    # Green LED off: GPIO209 → drive low
    run pinctrl set 209 op dl

    echo "LEDs off."
}

led_on() {
    # Restore kernel triggers
    tee_write mmc0 /sys/devices/platform/soc@107c000000/1000fff000.mmc/leds/mmc0::/trigger
    tee_write mmc0 /sys/devices/platform/leds/leds/ACT/trigger

    # Red LED on: GPIO44 → drive low
    run pinctrl set 44 op dl

    # Green LED on: GPIO209 → drive high (mmc0 trigger will take over)
    run pinctrl set 209 op dh

    echo "LEDs on."
}

case "$1" in
    -off)
        led_off
        ;;
    -on)
        led_on
        ;;
    *)
        echo "Usage: $0 -off | -on"
        echo ""
        echo "  -off   Turn off both status LEDs (green ACT and red PWR)"
        echo "  -on    Restore LEDs to default state"
        echo ""
        echo "GPIO mapping (Pi 5):"
        echo "  GPIO44  (RP1_STAT_LED)  = red LED:   dh=off, dl=on"
        echo "  GPIO209 (2712_STAT_LED) = green LED: dl=off, dh=on"
        ;;
esac
