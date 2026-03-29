# OpenNetty Home Assistant Add-on

OpenWebNet/MQTT gateway for BTicino and Legrand home automation devices.

This add-on bridges [OpenWebNet](https://en.wikipedia.org/wiki/OpenWebNet) gateways to MQTT, enabling Home Assistant to control and monitor BTicino and Legrand devices via [MQTT Discovery](https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery).

## Supported protocols

- **OpenWebNet/Zigbee** - MyHome Play devices (via BTicino 3578 or Legrand 88328 Zigbee/USB gateway)
- **OpenWebNet/Nitoo** - In One by Legrand devices (via Legrand 88213 powerline/USB gateway)
- **OpenWebNet/SCS** - MyHome/MyHome Up devices (via BTicino F454 or MH202 SCS/Ethernet gateway)

## Supported devices

The full list of supported BTicino and Legrand products can be found in the [`OpenNettyDevices.xml`](src/OpenNetty/OpenNettyDevices.xml) file.

## Installation

1. Add this repository to your Home Assistant add-on store:

   [![Add repository](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FIsraelBenDavid%2Fopennetty-core)

   Or manually add the repository URL:
   ```
   https://github.com/IsraelBenDavid/opennetty-core
   ```

2. Install the **OpenNetty** add-on from the store.
3. Configure the add-on (see below).
4. Start the add-on.

## Configuration

### MQTT

| Option | Description | Required |
|--------|-------------|----------|
| `mqtt_server` | Hostname or IP of your MQTT broker (e.g. `core-mosquitto`) | Yes |
| `mqtt_port` | MQTT broker port (default `1883`, or `8883` for TLS) | Yes |
| `mqtt_username` | MQTT broker username | Yes |
| `mqtt_password` | MQTT broker password | Yes |

### MQTT TLS (optional)

| Option | Description |
|--------|-------------|
| `mqtt_tls_enabled` | Enable TLS/SSL for the MQTT connection |
| `mqtt_tls_ca_cert` | CA certificate filename in the `/ssl` directory (e.g. `ca.crt`) |
| `mqtt_tls_client_cert` | Client certificate filename in the `/ssl` directory (e.g. `client.crt`) |
| `mqtt_tls_client_key` | Client private key filename in the `/ssl` directory (e.g. `client.key`) |
| `mqtt_tls_server_host` | Expected server hostname for TLS certificate validation |

### Gateways

Add your OpenWebNet gateways under the `gateways` list. Each gateway requires:

| Option | Description | Required |
|--------|-------------|----------|
| `brand` | `Legrand` or `BTicino` | Yes |
| `model` | Gateway model number (e.g. `88328`, `F454`) | Yes |
| `serial_number` | Serial number (or MAC address for TCP gateways, e.g. `00:03:50:A2:27:1B`) | Yes |
| `gateway_name` | A friendly name for the gateway | Yes |
| `gateway_type` | `Serial` or `Tcp` | Yes |
| `port` | Serial port path (for Serial gateways) | Serial only |
| `server` | IP address (for TCP gateways) | Tcp only |
| `password` | Gateway password (for TCP gateways requiring authentication) | If required |

### General

| Option | Description | Default |
|--------|-------------|---------|
| `ha_discovery_culture` | Language for HA discovery payloads (e.g. `en`, `fr`). Leave empty for system default. | empty |
| `debug_logging` | Enable detailed logging output for troubleshooting | `false` |

### Scan delay settings

These settings control the timing of the Zigbee discovery scan. Adjust them if you experience issues with device detection on busy networks.

| Option | Description | Default |
|--------|-------------|---------|
| `scan_retry_no_response_delay` | Delay (ms) before retrying when no response is received | `2000` |
| `scan_retry_error_delay` | Delay (ms) before retrying after an error | `3000` |
| `scan_inter_device_delay` | Delay (ms) between querying each device | `1000` |
| `scan_query_timeout` | Timeout (ms) for waiting for a product info response | `5000` |

Set any value to `0` to disable the delay.

## Example configuration

```yaml
mqtt_server: core-mosquitto
mqtt_port: 1883
mqtt_username: opennetty
mqtt_password: my_password
mqtt_tls_enabled: false
ha_discovery_culture: en
debug_logging: false
scan_retry_no_response_delay: 2000
scan_retry_error_delay: 3000
scan_inter_device_delay: 1000
scan_query_timeout: 5000
gateways:
  - brand: Legrand
    model: "88328"
    serial_number: "0026BD26"
    gateway_name: Zigbee Gateway
    gateway_type: Serial
    port: /dev/serial/by-id/usb-Silicon_Labs_CP2102_USB_to_UART_Bridge_Controller_0001-if00-port0
  - brand: BTicino
    model: F454
    serial_number: "00:03:50:A2:27:1B"
    gateway_name: SCS Gateway
    gateway_type: Tcp
    server: 192.168.1.10
    password: my_gateway_password
```

## How it works

Once configured and started, the add-on:

1. Connects to your OpenWebNet gateways (Serial or TCP).
2. Publishes MQTT Discovery payloads so Home Assistant automatically creates entities for all detected devices.
3. Bridges state changes and commands between OpenWebNet and MQTT in real time.
4. For Zigbee gateways, performs a discovery scan to automatically detect connected devices.

Devices appear automatically in Home Assistant under the MQTT integration - no additional configuration needed.

## Troubleshooting

- Enable **Debug Logging** in the add-on configuration for detailed output.
- Check the add-on logs in the Home Assistant Supervisor panel.
- For Zigbee scan issues, try increasing the scan delay values.
- Ensure your MQTT broker (e.g. Mosquitto) is running and accessible.

## License

This project is licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0.html).

Based on [OpenNetty](https://github.com/opennetty/opennetty-core) by [Kevin Chalet](https://github.com/kevinchalet).
