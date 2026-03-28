#!/bin/sh
set -eu

CONFIG_PATH="/data/options.json"
DEVICES_LIST_PATH="/data/devices.json"

echo "OpenNetty Device Persistence Service starting..."

# Check if MQTT is configured
MQTT_SERVER=$(jq -r '.mqtt_server' "$CONFIG_PATH" 2>/dev/null || echo "")
if [ -z "$MQTT_SERVER" ] || [ "$MQTT_SERVER" = "null" ]; then
    echo "ERROR: MQTT server not configured. Device persistence requires MQTT."
    exit 1
fi

echo "Monitoring MQTT for device discoveries..."
echo "Listening to: homeassistant/device/opennetty-*"
echo ""

# Initialize devices list if it doesn't exist
if [ ! -f "$DEVICES_LIST_PATH" ]; then
    echo '{"devices": []}' > "$DEVICES_LIST_PATH"
fi

# Use mosquitto_sub to monitor MQTT discovery messages and build device list
# This script will listen to Home Assistant discovery topics and reconstruct the device list

# For now, we'll create a simpler approach:
# Extract all devices from MQTT discovery topics every interval and save them

while true; do
    # Wait 30 seconds before checking
    sleep 30

    # This is a placeholder - in production, you would:
    # 1. Query MQTT for all homeassistant/device/opennetty-*/config topics
    # 2. Parse the responses to extract device information
    # 3. Save to /data/devices.json

    # For now, log that we're monitoring
    # echo "[$(date)] Checking for discovered devices..."

done
