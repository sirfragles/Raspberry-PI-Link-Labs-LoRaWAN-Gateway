#!/bin/bash
# Drive Link Labs hat LEDs based on Basic Station connection state.
#
# LED1 = BCM27 (pin 13)  -- solid ON when fully connected to TTN
#                           (router_config received, region configured),
#                           OFF on muxs error / reconnect backoff.
# LED2 = BCM25 (pin 22)  -- 100ms blink every 2s as a process heartbeat
#                           (independent of network state).
#
# Connection state is inferred from journalctl -fu linklabs by matching
# Basic Station log lines, since the daemon exposes no status API.
#
# Connect marker:    "[S2E:INFO] Configuring for region"
#   (printed after the LNS pushes router_config; this is the real
#    "fully up" signal -- the earlier "Infos: ..." line is just the
#    INFOS handshake that always closes with an SSL notification.)
# Disconnect markers:
#   "Closing connection to muxs - error in s2e_onMsg"
#   "INFOS reconnect backoff"
#   "Connection to MUXS lost"

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
        GREP='Configuring for region|Closing connection to muxs|INFOS reconnect backoff|Connection to MUXS lost'

        # Seed LED1 from the most recent matching event in history.
        # Otherwise --since=now misses an already-established connection
        # and LED1 stays dark even though the gateway is healthy.
        LAST=$(journalctl -u linklabs.service -o cat --no-pager \
                   --grep="$GREP" | tail -n 1)
        case "$LAST" in
            *"Configuring for region"*) set_led "$LED1" 1 ;;
            *)                          set_led "$LED1" 0 ;;
        esac

        # Then follow new events.
        journalctl -fu linklabs.service --since=now -o cat --grep="$GREP" \
        | while IFS= read -r line; do
            case "$line" in
                *"Configuring for region
            *"Connected to MUXS"*) set_led "$LED1" 1 ;;
            *)                     set_led "$LED1" 0 ;;
        esac

        # Then follow new events.
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
