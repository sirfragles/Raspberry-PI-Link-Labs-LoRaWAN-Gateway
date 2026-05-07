#!/bin/bash
# Wait for DNS, then exec Basic Station with the runtime dir.

while ! getent hosts eu1.cloud.thethings.network >/dev/null 2>&1; do
    echo "[LoRa Gateway]: Waiting for network / DNS..."
    sleep 10
done

if [ ! -f /opt/linklabs/station/tc.key ]; then
    echo "[LoRa Gateway]: ERROR - /opt/linklabs/station/tc.key is missing." >&2
    echo "[LoRa Gateway]: Register the gateway in TTN, paste API key into tc.key, retry." >&2
    exit 1
fi

# One-shot GPS reset (BCM GPIO6 / RPi pin 31). Done here because the
# Basic Station -i hook has a 200ms budget, too tight for both resets.
raspi-gpio set 6 op dl
sleep 0.1
raspi-gpio set 6 dh
sleep 0.1
raspi-gpio set 6 dl

cd /opt/linklabs/station
export RADIODEV=/dev/spidev0.0
exec ./station -h /opt/linklabs/station -i /opt/linklabs/station/reset_lgw.sh
