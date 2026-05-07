#!/bin/bash
# Drive Link Labs hat LEDs based on Basic Station connection state.
#
# LED1 = BCM27 (pin 13)  -- solid ON when connected to the TTN MUXS,
#                           OFF while disconnected / reconnecting.
# LED2 = BCM25 (pin 22)  -- 100ms blink every 2s as a process heartbeat
#                           (independent of network state).
#
# Connection state is inferred from journalctl -fu linklabs by matching
# Basic Station log lines, since the daemon exposes no status API.

LED1=27
LED2=25

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
    on)        set_led "$2" 1 ;;
    off)       set_led "$2" 0 ;;
    init-off)
        set_led "$LED1" 0
        set_led "$LED2" 0
        ;;
    run)
        trap cleanup TERM INT
        set_led "$LED1" 0
        set_led "$LED2" 0

        # LED2 = process heartbeat (separate background loop).
        heartbeat_loop &
        BLINK_PID=$!

        # LED1 follows TTN connection state, parsed from Basic Station logs.
        # --since=now avoids stale "Connected to MUXS" matches from before
        # this service started. --grep filters on the daemon side so we
        # only get events relevant to LED1, keeping CPU/journal noise low.
        journalctl -fu linklabs.service --since=now -o cat \
            --grep='Connected to MUXS|Closing connection to muxs|INFOS reconnect backoff|Connection to MUXS lost' \
        | while IFS= read -r line; do
            case "$line" in
                *"Connected to MUXS"*)
                    set_led "$LED1" 1
                    ;;
                *)
                    set_led "$LED1" 0
                    ;;
            esac
        done
        ;;
    *)
        echo "Usage: $0 {on|off <bcm-pin>} | init-off | run" >&2
        exit 1
        ;;
esac
