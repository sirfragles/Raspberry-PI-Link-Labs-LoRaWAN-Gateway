#!/bin/bash
# Basic Station installer for Link Labs RPi LoRaWAN hat (SX1301) on Raspbian Bullseye.

set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

echo "Link Labs Gateway installer (Basic Station)"

# Update the gateway installer to the correct branch
echo "Updating installer files..."
VERSION="spi"
OLD_HEAD=$(git rev-parse HEAD)
git fetch
git checkout -q $VERSION
git pull
NEW_HEAD=$(git rev-parse HEAD)

if [[ $OLD_HEAD != $NEW_HEAD ]]; then
    echo "New installer found. Restarting process..."
    exec ./install.sh "$@"
fi

# Dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y build-essential git raspi-gpio ca-certificates curl

INSTALL_DIR="/opt/linklabs"
STATION_DIR="$INSTALL_DIR/station"
SRC_DIR="$INSTALL_DIR/src"

mkdir -p "$INSTALL_DIR" "$SRC_DIR"

# Build Basic Station
pushd "$SRC_DIR"
if [ ! -d basicstation ]; then
    git clone --branch v2.0.6 https://github.com/lorabasics/basicstation.git
fi
pushd basicstation
git reset --hard
# Build for Raspberry Pi, standard SX1301 driver (works for Link Labs / IMST hats).
make platform=rpi variant=std
popd
popd

# Lay out runtime directory
mkdir -p "$STATION_DIR"
cp -f "$SRC_DIR/basicstation/build-rpi-std/bin/station" "$STATION_DIR/station"

# Copy configuration (does not overwrite existing local edits if present).
cp -n ./station/station.conf "$STATION_DIR/station.conf"
cp -n ./station/tc.uri        "$STATION_DIR/tc.uri"
cp -n ./station/tc.key.example "$STATION_DIR/tc.key.example"
cp -f ./station/reset_lgw.sh   "$STATION_DIR/reset_lgw.sh"
chmod +x "$STATION_DIR/reset_lgw.sh"

# Fetch LetsEncrypt root CA for TTN LNS WSS endpoint.
if [ ! -f "$STATION_DIR/tc.trust" ]; then
    curl -fsSL -o "$STATION_DIR/tc.trust" https://letsencrypt.org/certs/isrgrootx1.pem
fi

# Generate Gateway EUI from eth0 MAC if not already present.
if [ ! -f "$STATION_DIR/station.eui" ]; then
    MAC=$(cat /sys/class/net/eth0/address | tr -d ':')
    EUI="${MAC:0:6}FFFE${MAC:6:6}"
    echo "$EUI" | tr 'a-f' 'A-F' > "$STATION_DIR/station.eui"
fi

echo
echo "Gateway EUI: $(cat $STATION_DIR/station.eui)"
echo
if [ ! -f "$STATION_DIR/tc.key" ]; then
    echo ">>> ACTION REQUIRED: register this EUI in TTN console as Basic Station,"
    echo "    generate a Gateway API key, then write it to:"
    echo "        $STATION_DIR/tc.key"
    echo "    (file format: a single line, e.g. \"Authorization: Bearer NNSXS.xxxxx\")"
    echo "    See $STATION_DIR/tc.key.example for the template."
fi

# Install start script + systemd service
mkdir -p "$INSTALL_DIR/bin"
cp -f ./start.sh "$INSTALL_DIR/bin/start.sh"
cp -f ./leds.sh  "$INSTALL_DIR/bin/leds.sh"
chmod +x "$INSTALL_DIR/bin/start.sh" "$INSTALL_DIR/bin/leds.sh"

cp ./linklabs.service       /etc/systemd/system/
cp ./linklabs-leds.service  /etc/systemd/system/
systemctl daemon-reload
systemctl enable linklabs.service
systemctl enable linklabs-leds.service

echo "Installation completed."
echo "Start the gateway with: sudo systemctl start linklabs"
