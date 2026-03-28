# OpenNetty Home Assistant Add-on

## Overview

OpenNetty is an OpenWebNet/MQTT gateway that enables integration of BTicino and Legrand
home automation devices with Home Assistant. It supports three OpenWebNet protocol variants:

- **OpenWebNet (SCS)** — for MyHome/MyHome Up products
- **OpenWebNet/Nitoo** — for In One by Legrand products
- **OpenWebNet/Zigbee** — for MyHome Play products

The add-on connects to your OpenWebNet gateways, translates device states and commands
into MQTT messages, and uses Home Assistant MQTT Discovery to automatically create entities.

## Prerequisites

- An MQTT broker (the Mosquitto add-on works well)
- One or more supported OpenWebNet gateways:
  - **Legrand 88213** — In One by Legrand (Serial/USB)
  - **Legrand 88328** — MyHome Play / Zigbee (Serial/USB)
  - **BTicino F454** — MyHome Up / SCS (Ethernet/TCP)
  - **BTicino MH202** — MyHome Up / SCS (Ethernet/TCP)
  - **BTicino 3578** — MyHome Play / Zigbee (Serial/USB)

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top right) and select **Repositories**.
3. Add this repository URL: `https://github.com/IsraelBenDavid/opennetty-core`
4. Find **OpenNetty** in the add-on list and click **Install**.

## Configuration

### MQTT Settings

| Option | Description |
|--------|-------------|
| `mqtt_server` | MQTT broker hostname/IP (use `core-mosquitto` for the HA Mosquitto add-on) |
| `mqtt_port` | MQTT broker port (default: `1883`) |
| `mqtt_username` | MQTT username |
| `mqtt_password` | MQTT password |
| `mqtt_tls_enabled` | Set to `true` to enable TLS |
| `mqtt_tls_ca_cert` | CA certificate filename in `/ssl` |
| `mqtt_tls_client_cert` | Client certificate filename in `/ssl` |
| `mqtt_tls_client_key` | Client private key filename in `/ssl` |
| `mqtt_tls_server_host` | Expected TLS server hostname |
| `ha_discovery_culture` | Language for discovery payloads (`en`, `fr`, or empty for default) |

### Gateways

Add one entry per physical OpenWebNet gateway:

| Field | Description |
|-------|-------------|
| `brand` | `Legrand` or `BTicino` |
| `model` | Device model number (e.g. `88328`, `F454`) |
| `serial_number` | Serial number (or MAC address for TCP gateways like `00:03:50:A2:27:1B`) |
| `gateway_name` | A friendly name (e.g. `OPEN-Zigbee gateway`) |
| `gateway_type` | `Serial` for USB gateways or `Tcp` for Ethernet gateways |
| `port` | Serial device path (e.g. `/dev/serial/by-id/usb-...`) — for Serial gateways |
| `server` | IP address — for TCP gateways |
| `password` | Gateway password — for TCP gateways that require authentication |

### Devices

Add one entry per BTicino/Legrand device with its endpoints:

| Field | Description |
|-------|-------------|
| `brand` | `Legrand` or `BTicino` |
| `model` | Device model number |
| `serial_number` | Device serial number |
| `units[].unit_id` | Unit/module identifier (see `OpenNettyDevices.xml` for valid IDs) |
| `units[].endpoint_name` | Friendly name used as the MQTT topic (e.g. `Bedroom/Wall light`) |

## Logs

View add-on logs directly in the Home Assistant UI:

1. Go to **Settings → Add-ons → OpenNetty**.
2. Click the **Log** tab to view real-time output.

The add-on logs include connection status, device discovery events, and any errors.

## Supported Devices

The complete list of supported BTicino and Legrand products can be found in the
[`OpenNettyDevices.xml`](https://github.com/IsraelBenDavid/opennetty-core/blob/HA-addon/src/OpenNetty/OpenNettyDevices.xml) file.
