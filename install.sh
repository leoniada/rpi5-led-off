#!/bin/bash
set -e

if [ "$(id -u)" != "0" ]; then
    echo "Run as root: sudo bash install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing led5off..."

install -m 755 "$SCRIPT_DIR/led5off.sh"      /usr/local/bin/led5off.sh
install -m 644 "$SCRIPT_DIR/led5off.service" /etc/systemd/system/led5off.service
install -m 644 "$SCRIPT_DIR/led5off.timer"   /etc/systemd/system/led5off.timer

systemctl daemon-reload
systemctl enable led5off.timer
systemctl start led5off.timer

echo "Done. LEDs will turn off 3 minutes after every boot."
echo "To turn them off now: sudo systemctl start led5off.service"
