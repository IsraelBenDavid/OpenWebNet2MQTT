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

### Step 3: Add Devices (Optional)

Devices are the individual BTicino/Legrand switches, lights, thermostats, etc. connected to your gateways.

Add one entry per device by clicking **Add** under the **Devices** section:

| Field | Description | Example |
|-------|-------------|---------|
| `brand` | `Legrand` or `BTicino` | `Legrand` |
| `model` | Device model number | `67201` (for PLC switch) |
| `serial_number` | Device serial number | `597132` |
| `units[].unit_id` | Unit/module identifier | `2` |
| `units[].endpoint_name` | Friendly name (becomes MQTT topic) | `Bedroom/Wall light` |

**Example Device with Units:**
```yaml
brand: Legrand
model: "67202"
serial_number: "479632"
units:
  - unit_id: "3"
    endpoint_name: "Bedroom/Bedside lamp 1"
  - unit_id: "4"
    endpoint_name: "Bedroom/Bedside lamp 2"
```

> **Tip:** For Zigbee and In One devices, units are often auto-discovered. You may not need to add them explicitly unless you want custom names.

Click **Save** once all configuration is complete.

## Starting the Add-on

1. Go to the **Info** tab
2. (Optional) Toggle **Start on boot** to enable auto-start
3. Click the **Start** button

The daemon will:
- Connect to your MQTT broker
- Initialize connections to your gateways
- Begin discovering and monitoring devices
- Publish MQTT discovery messages for Home Assistant

## Automatic Device Discovery

When the add-on starts, it automatically scans your configured gateways and discovers connected devices. These discovered devices are saved to `/data/discovered-devices.json` and automatically added to your configuration.

**How it works:**
1. On startup, the daemon scans each gateway for connected devices
2. New devices are discovered and saved to `/data/discovered-devices.json`
3. These devices are merged with your manually configured devices
4. All devices (configured + discovered) are added to the MQTT discovery process

**Using discovered devices:**
- Discovered devices appear automatically in Home Assistant through MQTT Discovery
- You can view all discovered devices by checking the add-on logs
- To make discovered devices permanent, copy them from the log and add them to your **Configuration** → **Devices** section
- Devices already in your manual configuration are not duplicated

**Example log output:**
```
Configuration summary:
  MQTT Server: 192.168.68.124:1883
  Gateways configured: 1
  Devices configured: 0
  Devices discovered: 3
```

## Viewing Logs

Go to the **Logs** tab to view real-time output:
- Connection status to MQTT and gateways
- Device discovery and initialization
- Discovered devices as they appear
- State changes and commands
- Any errors or warnings

Look for lines like:
```
Found discovered devices file, merging...
Skipping discovered device XXXXXXXX (already configured)
```

to see device discovery in action.

## Troubleshooting

### "The device model X is not valid"
- Check that the model number is correct (e.g., `3578` for Zigbee, `F454` for SCS)
- See the supported devices list below

### "The specified identifier is not a valid hexadecimal"
- Zigbee devices require hex serial numbers (0-9, A-F only)
- Example valid: `0026BD26`, `00047400`
- Example invalid: `gggggg` (contains letters g, h, i, etc.)

### "The frame was rejected by the gateway"
- Check that the serial port or TCP connection details are correct
- Verify the gateway is powered on and accessible
- Try a different serial port if using USB

### No MQTT messages appearing
- Verify MQTT broker connection details (server, port, credentials)
- Check that username/password are correct for your MQTT broker
- Ensure the MQTT broker is running and accessible

## Supported Devices

The complete list of supported BTicino and Legrand products can be found in the
[`OpenNettyDevices.xml`](https://github.com/IsraelBenDavid/opennetty-core/blob/HA-addon/src/OpenNetty/OpenNettyDevices.xml) file.

Key supported families:
- **In One by Legrand** — Powerline/Radio devices (model 672xx series)
- **MyHome/MyHome Up** — SCS-based devices (F454, MH202 gateways)
- **MyHome Play** — Zigbee devices (3578 gateway, various endpoints)
