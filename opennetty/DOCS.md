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

### Step 1: Configure MQTT Connection

In the add-on's **Configuration** tab:

| Option | Description |
|--------|-------------|
| `mqtt_server` | MQTT broker hostname/IP (use `core-mosquitto` for the HA Mosquitto add-on, or your MQTT broker IP) |
| `mqtt_port` | MQTT broker port (default: `1883`) |
| `mqtt_username` | MQTT username |
| `mqtt_password` | MQTT password |
| `mqtt_tls_enabled` | Set to `true` to enable TLS |
| `mqtt_tls_ca_cert` | CA certificate filename in `/ssl` |
| `mqtt_tls_client_cert` | Client certificate filename in `/ssl` |
| `mqtt_tls_client_key` | Client private key filename in `/ssl` |
| `mqtt_tls_server_host` | Expected TLS server hostname |
| `ha_discovery_culture` | Language for discovery payloads (`en`, `fr`, or empty for default) |

Click **Save** once MQTT is configured.

### Step 2: Add Gateways

Gateways are the physical OpenWebNet devices (serial/USB or Ethernet) that connect to your home automation devices.

Add one entry per gateway by clicking **Add** under the **Gateways** section:

| Field | Description | Example |
|-------|-------------|---------|
| `brand` | `Legrand` or `BTicino` | `BTicino` |
| `model` | Device model number | `3578` (for Zigbee) or `F454` (for SCS) |
| `serial_number` | Serial number or MAC address (hex for Zigbee) | `0026BD26` (hex) or `00:03:50:A2:27:1B` (MAC) |
| `gateway_name` | Friendly name for logs/identification | `OPEN-Zigbee gateway` |
| `gateway_type` | `Serial` for USB/Serial gateways or `Tcp` for Ethernet | `Serial` |
| `port` | Serial device path (for Serial gateways) | `/dev/ttyUSB0` |
| `server` | IP address (for TCP gateways) | `192.168.1.100` |
| `password` | Gateway password (for TCP gateways that require it) | `aJhYiBHk8` |

**Example Zigbee Gateway:**
```yaml
brand: BTicino
model: "3578"
serial_number: "0026BD26"
gateway_name: "OPEN-Zigbee gateway"
gateway_type: Serial
port: "/dev/ttyUSB0"
server: ""
password: ""
```

**Example SCS/Ethernet Gateway:**
```yaml
brand: BTicino
model: "F454"
serial_number: "00:03:50:A2:27:1B"
gateway_name: "OPEN-SCS gateway"
gateway_type: Tcp
port: ""
server: "192.168.1.100"
password: "aJhYiBHk8"
```

Click **Save** once all gateways are configured.

## Starting the Add-on

1. Go to the **Info** tab
2. (Optional) Toggle **Start on boot** to enable auto-start
3. Click the **Start** button

The daemon will:
- Connect to your MQTT broker
- Initialize connections to your gateways
- Wait for you to scan devices

## Automatic Device Discovery

The add-on manages devices automatically for you. Unlike gateways which you configure manually, devices are discovered and managed by the system.

### How Device Discovery Works

1. **Initial Start** — Daemon connects to configured gateways via the configured MQTT broker
2. **Device Scan** — When you request a device scan, the add-on queries all gateways
3. **Automatic Save** — Discovered devices are automatically saved to `/data/devices.json` (internal list)
4. **Auto-Load on Restart** — When the daemon restarts, it automatically loads the saved device list
5. **No Manual Management** — You don't edit the device list manually; the system keeps it updated

### Scanning for Devices

Devices are automatically discovered when:
- The add-on first starts and connects to gateways
- You manually trigger a device scan
- New devices are added to your gateways

The discovered devices are saved persistently and used every time the daemon restarts.

### Device List Location

The internal device list is stored at: `/data/devices.json`

This file is:
- ✅ Automatically created and updated by the add-on
- ✅ Persisted across add-on restarts
- ✅ NOT user-editable (managed by the system)
- ✅ Loaded automatically at startup

## Viewing Logs

Go to the **Logs** tab to view real-time output:
- Connection status to MQTT and gateways
- Device discovery events
- State changes and commands
- Any errors or warnings

Example log output:
```
Loading devices from internal list...
Configuration summary:
  MQTT Server: 192.168.68.124:1883
  Gateways configured: 1
  Devices in internal list: 3
```

## Supported Devices

The complete list of supported BTicino and Legrand products can be found in the
[`OpenNettyDevices.xml`](https://github.com/IsraelBenDavid/opennetty-core/blob/HA-addon/src/OpenNetty/OpenNettyDevices.xml) file.

Key supported families:
- **In One by Legrand** — Powerline/Radio devices (model 672xx series)
- **MyHome/MyHome Up** — SCS-based devices (F454, MH202 gateways)
- **MyHome Play** — Zigbee devices (3578 gateway, various endpoints)

## Troubleshooting

### "No devices are appearing"
- Make sure at least one gateway is configured in the **Configuration** tab
- Check that the gateway is powered on and connected
- Verify MQTT connection is working (check logs for connection errors)
- The daemon needs to be running and connected to discover devices

### "The device model X is not valid"
- Check that the gateway model number is correct
- Supported models: `3578` (Zigbee), `F454` (SCS), `88213` (In One), etc.
- See supported devices list above

### "The specified identifier is not a valid hexadecimal"
- Zigbee gateways require hex serial numbers (0-9, A-F only)
- Example valid: `0026BD26`, `00047400`
- Example invalid: `gggggg`, `xyz123`

### "Connection refused" errors
- Check that your MQTT broker is running and accessible
- Verify the MQTT server address and port are correct
- Check username and password if MQTT authentication is enabled

## Advanced: Managing the Device List

If you need to manually inspect or modify the device list:

```bash
# View the current device list
cat /data/devices.json

# Clear the device list (will be repopulated on next scan)
echo '{"devices": []}' > /data/devices.json
```

However, under normal usage, you should not need to manually edit this file.
