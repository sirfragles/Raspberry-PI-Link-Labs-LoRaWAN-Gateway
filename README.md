# Raspberry Pi + Link Labs LoRaWAN Gateway (Basic Station, TTN v3)

Installer for a [The Things Network](https://www.thethingsnetwork.org/) LoRaWAN
gateway built from a Raspberry Pi host and a [Link Labs Gateway Board](http://store.link-labs.com/products/lorawan-raspberry-pi-board)
(SX1301 concentrator). This branch (`spi`) targets:

- **Raspbian Bullseye** (and newer) on Raspberry Pi 2/3/4.
- **The Things Stack v3** (`eu1.cloud.thethings.network`).
- **Basic Station** packet forwarder (TLS over WebSocket, port 8887).

The legacy Semtech UDP packet forwarder (`packet_forwarder` v2.x) has been
replaced with [`lorabasics/basicstation`](https://github.com/lorabasics/basicstation)
v2.0.6.

## Hardware

[Schematic](http://forum.thethingsnetwork.org/uploads/default/original/1X/dbdd7deb2b854bb7104019d79683f2d1ae9f1c51.pdf)

| Description    | RPi pin | BCM GPIO | Mode   |
| :---           | :---:   | :---:    | :---:  |
| SX1301 Reset   | 29      | GPIO5    | output |
| GPS Reset      | 31      | GPIO6    | output |
| GPS PPS        | 7       | GPIO4    | input  |
| SPI CLK        | 23      |          |        |
| SPI MISO       | 21      |          |        |
| SPI MOSI       | 19      |          |        |
| SPI NSS        | 24      |          |        |
| LED 1          | 13      | GPIO27   | output |
| LED 2          | 22      | GPIO25   | output |

**Warning**: never power up the concentrator without an antenna connected.

## OS prerequisites

1. Flash [Raspberry Pi OS Lite (Bullseye or newer)](https://www.raspberrypi.com/software/operating-systems/).
2. SSH into the Pi.
3. Enable SPI (and optionally serial for GPS):
   ```bash
   sudo raspi-config
   #   Interface Options -> SPI       -> Enable
   #   Interface Options -> Serial    -> login shell: No, hardware: Yes (only if using GPS)
   ```
4. Reboot.

If you are using GPS on a Pi 3/4 (which has Bluetooth on `/dev/ttyAMA0`),
add to `/boot/config.txt`:
```
dtoverlay=disable-bt
enable_uart=1
```

## Install

```bash
sudo apt-get install -y git
git clone --branch spi https://github.com/sirfragles/Raspberry-PI-Link-Labs-LoRaWAN-Gateway.git ~/linklabs
cd ~/linklabs
sudo ./install.sh
```

The installer will:
1. Install build deps (`build-essential`, `git`, `raspi-gpio`, `ca-certificates`, `curl`).
2. Clone and build `basicstation v2.0.6` (`make platform=rpi variant=std`).
3. Lay out `/opt/linklabs/`:
   ```
   /opt/linklabs/
   ├── bin/start.sh                 (systemd entry point)
   ├── src/basicstation/...         (sources + build tree)
   └── station/
       ├── station                  (compiled binary)
       ├── station.conf             (SX1301 + EU868 channel plan)
       ├── station.eui              (auto-generated from eth0 MAC)
       ├── tc.uri                   (LNS endpoint, wss://eu1.cloud.thethings.network:8887)
       ├── tc.trust                 (LetsEncrypt ISRG Root X1)
       ├── tc.key                   (YOUR TTN API key — see below)
       └── reset_lgw.sh             (radio reset hook)
   ```
4. Install and enable the `linklabs.service` systemd unit.

After install the script prints the **Gateway EUI** (16 hex digits, format
`B827EBFFFE______`). Save it.

## Register in TTN console

1. Go to https://eu1.cloud.thethings.network → Console → **Gateways** →
   **Add gateway**.
2. Fill in:
   - **Owner**: your account/organization.
   - **Gateway EUI**: the EUI printed by the installer.
   - **Gateway ID**: any lower-case unique slug, e.g. `linklabs-rpi-home`.
   - **Frequency plan**: `Europe 863-870 MHz (SF9 for RX2 - recommended)`.
   - **Choose this option eg. if your gateway is powered by LoRa Basic Station**:
     ✅ enabled.
   - **Require authenticated connection**: ✅ enabled.
3. Submit.
4. On the new gateway page → **API keys** → **Add API key**:
   - Name: `basicstation-lns`.
   - Grant individual rights:
     - ✅ `Link as Gateway to a Gateway Server for traffic exchange`
     - ✅ `View gateway status` (optional)
   - Create. **Copy the key — it is shown only once** (`NNSXS.…`).

## Wire the API key on the gateway

```bash
sudo bash -c 'echo "Authorization: Bearer NNSXS.xxxxxxxxxxxxxxxxxxxxx" > /opt/linklabs/station/tc.key'
sudo chmod 600 /opt/linklabs/station/tc.key
sudo systemctl start linklabs
sudo journalctl -u linklabs -f
```

A healthy startup looks like:
```
[SYS:INFO] Station Ver  : 2.0.6
[TCE:INFO] Connecting to MUXS: wss://eu1.cloud.thethings.network:8887/traffic/eui-...
[any:INFO] Connected to MUXS.
[RAL:INFO] Concentrator started (~3s)
[S2E:INFO] Configuring for region: EU868 -- 863.0MHz..870.0MHz
```
The TTN console will flip the gateway to **Connected** within ~10 s.

## Day-to-day operations

| Task                        | Command                                       |
| :---                        | :---                                          |
| Status                      | `systemctl status linklabs`                   |
| Live logs                   | `journalctl -u linklabs -f`                   |
| Restart after config change | `sudo systemctl restart linklabs`             |
| Update from git             | `cd ~/linklabs && git pull && sudo ./install.sh` |
| Show Gateway EUI            | `cat /opt/linklabs/station/station.eui`       |

## Configuration files (under `/opt/linklabs/station/`)

| File              | Purpose                                                                                    | Tracked in git? |
| :---              | :---                                                                                       | :---            |
| `station.conf`    | SX1301 pinout + channel plan (mostly overridden by the LNS at runtime).                    | ✅              |
| `tc.uri`          | LNS WebSocket URL.                                                                         | ✅              |
| `tc.trust`        | TLS root CA bundle for the LNS endpoint (LetsEncrypt ISRG Root X1).                        | ❌ (per-host)   |
| `tc.key`          | `Authorization: Bearer …` header with your TTN gateway API key. **Secret.**                | ❌ (gitignored) |
| `station.eui`     | 16-hex-digit Gateway EUI, derived from eth0 MAC at install time.                           | ❌ (per-host)   |
| `reset_lgw.sh`    | Called by Basic Station via `-i` before each radio (re)init. Pulses SX1301 reset (BCM5).   | ✅              |

## Troubleshooting

**`Station proto EUI: '::0' must not be zero`**
`station.conf` should not contain `routerid`. The EUI is taken from `station.eui`.

**`@.SX1301_conf.radio_0.tx_freq_min: Illegal field`**
Basic Station rejects legacy `packet_forwarder` fields (`tx_freq_min`,
`tx_freq_max`, `antenna_gain`). Remove them.

**`Process /opt/linklabs/station/reset_lgw.sh did not terminate within 200ms`**
The radio init hook must finish in <200ms. Keep `reset_lgw.sh` to a couple of
`raspi-gpio` calls; do GPS reset elsewhere (e.g. in `start.sh` at boot).

**`SSL - The peer notified us that the connection is going to be closed`**
Usually a downstream config error (not a TLS problem). Check the line
*just after* this message — Basic Station prints the actual rejection reason
from the LNS.

**`[GPS:WARN] GGA sentence without a fix`**
GPS antenna has no sky view. Gateway works fine without GPS; only Class B
beaconing and µs timestamping are disabled. Either move the antenna outdoors
or remove the `gps`/`pps` keys from `station.conf`.

**`cannot open /dev/spidev0.0`**
SPI not enabled. Run `sudo raspi-config` → Interface Options → SPI → Enable,
then reboot.

## Credits

This project descends from:
- [`ttn-zh/ic880a-gateway`](https://github.com/ttn-zh/ic880a-gateway)
- [`mirakonta/Raspberry-PI-Link-Labs-LoRaWAN-Gateway`](https://github.com/mirakonta/Raspberry-PI-Link-Labs-LoRaWAN-Gateway)
- [Lorank8 installer](https://github.com/Ideetron/Lorank) by [Ruud Vlaming](https://github.com/devlaam).
