#!/bin/bash
# Basic Station calls this script with: $1 = "start" | "stop", $2 = SPI device path
# It must drive the SX1301 reset line (BCM GPIO5 = pin 29) and GPS reset (BCM GPIO6 = pin 31).

SX1301_RESET_PIN=5
GPS_RESET_PIN=6

case "$1" in
    start)
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
        ;;
    stop)
        raspi-gpio set $SX1301_RESET_PIN op dl
        raspi-gpio set $GPS_RESET_PIN op dl
        ;;
    *)
        echo "Usage: $0 {start|stop} [spi-device]" >&2
        exit 1
        ;;
esac
