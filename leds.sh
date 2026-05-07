#!/bin/bash
# Helpers to drive Link Labs hat LEDs via raspi-gpio.
# LED1 = BCM27 (pin 13)  -- service alive
# LED2 = BCM25 (pin 22)  -- radio heartbeat

LED1=27
LED2=25

set_led() {
    # set_led <bcm-pin> <0|1>
    if [ "$2" = "1" ]; then
        raspi-gpio set "$1" op dh
    else
        raspi-gpio set "$1" op dl
    fi
}

case "$1" in
    on)        set_led "$2" 1 ;;
    off)       set_led "$2" 0 ;;
    init-off)
        # Drive both LEDs low and configure as outputs.
        set_led "$LED1" 0
        set_led "$LED2" 0
        ;;
    heartbeat)
        # Blink LED2 forever while linklabs.service is active.
        # Exits on SIGTERM (systemd stop).
        trap 'set_led "$LED2" 0; exit 0' TERM INT
        set_led "$LED1" 1
        while systemctl is-active --quiet linklabs.service; do
            set_led "$LED2" 1
            sleep 0.1
            set_led "$LED2" 0
            sleep 1.9
        done
        set_led "$LED1" 0
        set_led "$LED2" 0
        ;;
    *)
        echo "Usage: $0 {on|off <bcm-pin>} | {init-off} | {heartbeat}" >&2
        exit 1
        ;;
esac
