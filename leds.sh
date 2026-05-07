#!/bin/bash
# Drive Link Labs hat LEDs based on Basic Station connection state.
#
# LED1 = BCM27 (pin 13)  -- solid ON when fully connected to TTN
#                           (router_config received, region configured),
#                           OFF on muxs error / reconnect backoff.
# LED2 = BCM25 (pin 22)  -- 100ms blink every 2s as a process heartbeat
#                           (independent of network state).

LED1=27
LED2=25

GREP='Configuring for region|Closing connection to muxs|INFOS reconnect backoff|Connection to MUXS lost'

set_led() {
    if [ "$2" = "1" ]; then
        raspi-gpio set "$1" op dh
    else
        raspi-gpio set "$1" op dl
    fi
}

cleanup() {
    set_led "$LED1" 0
    set_led "$LED2" 0
    [ -n "$BLINK_PID" ] && kill "$BLINK_PID" 2>/dev/null
    exit 0
}

heartbeat_loop() {
    trap 'set_led "$LED2" 0; exit 0' TERM INT
    while true; do
        set_led "$LED2" 1
        sleep 0.1
        set_led "$LED2" 0
        sleep 1.9
    done
}

case "$1" in
    on)
        set_led "$2" 1
        ;;
    off)
        set_led "$2" 0
        ;;
    init-off)
        set_led "$LED1" 0
        set_led "$LED2" 0
        ;;
    run)
        trap cleanup TERM INT
        set_led "$LED1" 0
        set_led "$LED2" 0

        heartbeat_loop &
        BLINK_PID=$!

        LAST=$(journalctl -u linklabs.service -o cat --no-pager --grep="$GREP" | tail -n 1)
        case "$LAST" in
            *"Configuring for region"*) set_led "$LED1" 1 ;;
            *)                          set_led "$LED1" 0 ;;
        esac

        journalctl -fu linklabs.service --since=now -o cat --grep="$GREP" \
        | while IFS= read -r line; do
            case "$line" in
                *"Configuring for region"*) set_led "$LED1" 1 ;;
                *)                          set_led "$LED1" 0 ;;
            esac
        done
        ;;
    *)
        echo "Usage: $0 {on|off <bcm-pin>} | init-off | run" >&2
        exit 1
        ;;
esac
