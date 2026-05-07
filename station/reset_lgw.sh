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
