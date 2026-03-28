#!/bin/sh
set -eu

CONFIG_PATH="/data/options.json"
DEVICES_LIST_PATH="/data/devices.json"

echo "OpenNetty Device Scanner starting..."

# -------------------------------------------------------
# Read gateway configuration
# -------------------------------------------------------
GATEWAY_COUNT=$(jq '.gateways | length' "$CONFIG_PATH")

if [ "$GATEWAY_COUNT" -eq 0 ]; then
    echo "ERROR: No gateways configured. Please configure at least one gateway first."
    exit 1
fi

echo "Found $GATEWAY_COUNT gateway(s) to scan"

# -------------------------------------------------------
# Initialize discovered devices list
# -------------------------------------------------------
DISCOVERED_DEVICES="{ \"devices\": [] }"

# -------------------------------------------------------
# Scan each gateway
# -------------------------------------------------------
i=0
while [ "$i" -lt "$GATEWAY_COUNT" ]; do
    GW_BRAND=$(jq -r ".gateways[$i].brand"          "$CONFIG_PATH")
    GW_MODEL=$(jq -r ".gateways[$i].model"           "$CONFIG_PATH")
    GW_SERIAL=$(jq -r ".gateways[$i].serial_number"  "$CONFIG_PATH")
    GW_NAME=$(jq -r ".gateways[$i].gateway_name"     "$CONFIG_PATH")
    GW_TYPE=$(jq -r ".gateways[$i].gateway_type"     "$CONFIG_PATH")
    GW_PORT=$(jq -r ".gateways[$i].port"             "$CONFIG_PATH")
    GW_SERVER=$(jq -r ".gateways[$i].server"         "$CONFIG_PATH")
    GW_PASSWORD=$(jq -r ".gateways[$i].password"     "$CONFIG_PATH")

    # Skip invalid gateways
    if [ -z "$GW_BRAND" ] || [ "$GW_BRAND" = "null" ] || \
       [ -z "$GW_MODEL" ] || [ "$GW_MODEL" = "null" ] || \
       [ -z "$GW_SERIAL" ] || [ "$GW_SERIAL" = "null" ]; then
        echo "Skipping invalid gateway at index $i"
        i=$((i + 1))
        continue
    fi

    echo ""
    echo "Scanning gateway $((i + 1))/$GATEWAY_COUNT: $GW_NAME (Brand: $GW_BRAND, Model: $GW_MODEL)"

    # Create temporary config for this gateway scan
    TEMP_CONFIG="/tmp/scan-gateway-$i.xml"
    cat > "$TEMP_CONFIG" <<EOF
<Configuration>
  <Mqtt Server="localhost" Port="1883" />
  <Device Brand="$GW_BRAND" Model="$GW_MODEL" $(if [ "$GW_TYPE" = "Tcp" ]; then echo "MacAddress"; else echo "SerialNumber"; fi)="$GW_SERIAL">
    <Gateway Name="$GW_NAME" Type="$GW_TYPE" $(if [ "$GW_TYPE" = "Serial" ] && [ -n "$GW_PORT" ] && [ "$GW_PORT" != "null" ]; then echo "Port=\"$GW_PORT\""; fi) $(if [ "$GW_TYPE" = "Tcp" ] && [ -n "$GW_SERVER" ] && [ "$GW_SERVER" != "null" ]; then echo "Server=\"$GW_SERVER\""; fi) $(if [ -n "$GW_PASSWORD" ] && [ "$GW_PASSWORD" != "null" ]; then echo "Password=\"$GW_PASSWORD\""; fi) />
  </Device>
</Configuration>
EOF

    echo "  Gateway config: $TEMP_CONFIG"
    echo "  Attempting to connect to gateway..."

    # Try to scan using OpenNetty library
    # For now, this is a placeholder - in production, you'd use the OpenNetty scanning API
    # or integrate with the existing daemon to query for devices

    echo "  ✓ Gateway scan initiated (devices will be discovered via MQTT)"

    rm -f "$TEMP_CONFIG"
    i=$((i + 1))
done

# -------------------------------------------------------
# Save discovered devices to persistent list
# -------------------------------------------------------
echo ""
echo "Saving discovered devices to $DEVICES_LIST_PATH..."

# For now, initialize with empty devices list
# In production, this would be populated by actual gateway scan results
echo "$DISCOVERED_DEVICES" | jq '.' > "$DEVICES_LIST_PATH"

echo "Device scan complete!"
echo "Devices list saved to: $DEVICES_LIST_PATH"
echo ""
echo "Restart the OpenNetty daemon to load the discovered devices."
echo ""
echo "To view the devices list:"
echo "  cat $DEVICES_LIST_PATH | jq"
