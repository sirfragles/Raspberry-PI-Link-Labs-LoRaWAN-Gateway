#!/bin/bash
# Invoked by Basic Station via `station -i <this script>` before each
# (re)initialization of the SX1301 radio. Basic Station kills this script
# after 200ms, so it MUST be fast — no sleeps, no GPS reset (that lives in
# start.sh and runs once at service boot).
#
# Pulse SX1301 reset line: BCM GPIO5 / RPi pin 29.

raspi-gpio set 5 op dh
raspi-gpio set 5 dl
exit 0
#!/bin/bash
# Invoked by Basic Station via `station -i <this script>` before each
# (re)initialization of the SX1301 radio. No argument contract — just toggle
# the SX1301 reset line (BCM GPIO5 / RPi pin 29) and the GPS reset line
# (BCM GPIO6 / RPi pin 31).

set -e

SX1301_RESET_PIN=5
GPS_RESET_PIN=6

raspi-gpio set $SX1301_RESET_PIN op dl
sleep 0.1
raspi-gpio set $SX1301_RESET_PIN dh
sleep 0.1
raspi-gpio set $SX1301_RESET_PIN dl
sleep 0.1

raspi-gpio set $GPS_RESET_PIN op dl
sleep 0.1
raspi-gpio set $GPS_RESET_PIN dh
sleep 0.1
raspi-gpio set $GPS_RESET_PIN dl
sleep 0.1

exit 0
