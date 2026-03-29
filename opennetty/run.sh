#!/bin/sh
set -eu

CONFIG_PATH="/data/options.json"
DEVICES_LIST_PATH="/data/devices.json"
XML_PATH="/app/OpenNettyConfiguration.xml"

echo "OpenNetty Home Assistant Add-on starting..."

# -------------------------------------------------------
# Read options from Home Assistant add-on configuration
# -------------------------------------------------------
MQTT_SERVER=$(jq -r '.mqtt_server'           "$CONFIG_PATH")
MQTT_PORT=$(jq -r '.mqtt_port'               "$CONFIG_PATH")
MQTT_USERNAME=$(jq -r '.mqtt_username'        "$CONFIG_PATH")
MQTT_PASSWORD=$(jq -r '.mqtt_password'        "$CONFIG_PATH")
MQTT_TLS_ENABLED=$(jq -r '.mqtt_tls_enabled'  "$CONFIG_PATH")
MQTT_TLS_CA=$(jq -r '.mqtt_tls_ca_cert'       "$CONFIG_PATH")
MQTT_TLS_CERT=$(jq -r '.mqtt_tls_client_cert' "$CONFIG_PATH")
MQTT_TLS_KEY=$(jq -r '.mqtt_tls_client_key'   "$CONFIG_PATH")
MQTT_TLS_HOST=$(jq -r '.mqtt_tls_server_host' "$CONFIG_PATH")
HA_CULTURE=$(jq -r '.ha_discovery_culture'     "$CONFIG_PATH")
DEBUG_LOGGING=$(jq -r '.debug_logging // false' "$CONFIG_PATH")

# -------------------------------------------------------
# Build the <Mqtt .../> element
# -------------------------------------------------------
MQTT_ATTRS="Server=\"${MQTT_SERVER}\" Port=\"${MQTT_PORT}\""

if [ -n "$MQTT_USERNAME" ] && [ "$MQTT_USERNAME" != "null" ]; then
    MQTT_ATTRS="${MQTT_ATTRS} Username=\"${MQTT_USERNAME}\""
fi
if [ -n "$MQTT_PASSWORD" ] && [ "$MQTT_PASSWORD" != "null" ]; then
    MQTT_ATTRS="${MQTT_ATTRS} Password=\"${MQTT_PASSWORD}\""
fi
if [ -n "$HA_CULTURE" ] && [ "$HA_CULTURE" != "null" ]; then
    MQTT_ATTRS="${MQTT_ATTRS} HomeAssistantDiscoveryUICulture=\"${HA_CULTURE}\""
fi

# TLS attributes
if [ "$MQTT_TLS_ENABLED" = "true" ]; then
    if [ -n "$MQTT_TLS_CA" ] && [ "$MQTT_TLS_CA" != "null" ]; then
        MQTT_ATTRS="${MQTT_ATTRS} TlsServerCertificateAuthorityFile=\"/ssl/${MQTT_TLS_CA}\""
    fi
    if [ -n "$MQTT_TLS_CERT" ] && [ "$MQTT_TLS_CERT" != "null" ]; then
        MQTT_ATTRS="${MQTT_ATTRS} TlsClientCertificateFile=\"/ssl/${MQTT_TLS_CERT}\""
    fi
    if [ -n "$MQTT_TLS_KEY" ] && [ "$MQTT_TLS_KEY" != "null" ]; then
        MQTT_ATTRS="${MQTT_ATTRS} TlsClientCertificatePrivateKeyFile=\"/ssl/${MQTT_TLS_KEY}\""
    fi
    if [ -n "$MQTT_TLS_HOST" ] && [ "$MQTT_TLS_HOST" != "null" ]; then
        MQTT_ATTRS="${MQTT_ATTRS} TlsServerTargetHost=\"${MQTT_TLS_HOST}\""
    fi
fi

# -------------------------------------------------------
# Build <Device> nodes for gateways
# -------------------------------------------------------
GATEWAY_XML=""
CONFIGURED_GATEWAYS="" # Add this line
GATEWAY_COUNT=$(jq '.gateways | length' "$CONFIG_PATH")

i=0
while [ "$i" -lt "$GATEWAY_COUNT" ]; do
    GW_BRAND=$(jq -r ".gateways[$i].brand"          "$CONFIG_PATH")
    GW_MODEL=$(jq -r ".gateways[$i].model"           "$CONFIG_PATH")
    GW_SERIAL=$(jq -r ".gateways[$i].serial_number"  "$CONFIG_PATH")
    
    CONFIGURED_GATEWAYS="${CONFIGURED_GATEWAYS} ${GW_SERIAL}" # Add this line
    
    GW_NAME=$(jq -r ".gateways[$i].gateway_name"     "$CONFIG_PATH")
    GW_TYPE=$(jq -r ".gateways[$i].gateway_type"     "$CONFIG_PATH")
    GW_PORT=$(jq -r ".gateways[$i].port"             "$CONFIG_PATH")
    GW_SERVER=$(jq -r ".gateways[$i].server"         "$CONFIG_PATH")
    GW_PASSWORD=$(jq -r ".gateways[$i].password"     "$CONFIG_PATH")

    # Skip entries with empty required fields
    if [ -z "$GW_BRAND" ] || [ "$GW_BRAND" = "null" ] || \
       [ -z "$GW_MODEL" ] || [ "$GW_MODEL" = "null" ] || \
       [ -z "$GW_SERIAL" ] || [ "$GW_SERIAL" = "null" ]; then
        i=$((i + 1))
        continue
    fi

    # Determine identifier attribute (MAC for TCP gateways, SerialNumber otherwise)
    ID_ATTR="SerialNumber=\"${GW_SERIAL}\""
    if [ "$GW_TYPE" = "Tcp" ]; then
        ID_ATTR="MacAddress=\"${GW_SERIAL}\""
    fi

    GW_ATTRS="Name=\"${GW_NAME}\" Type=\"${GW_TYPE}\""
    if [ "$GW_TYPE" = "Serial" ] && [ -n "$GW_PORT" ] && [ "$GW_PORT" != "null" ]; then
        GW_ATTRS="${GW_ATTRS} Port=\"${GW_PORT}\""
    fi
    if [ "$GW_TYPE" = "Tcp" ] && [ -n "$GW_SERVER" ] && [ "$GW_SERVER" != "null" ]; then
        GW_ATTRS="${GW_ATTRS} Server=\"${GW_SERVER}\""
    fi
    if [ -n "$GW_PASSWORD" ] && [ "$GW_PASSWORD" != "null" ]; then
        GW_ATTRS="${GW_ATTRS} Password=\"${GW_PASSWORD}\""
    fi

    GATEWAY_XML="${GATEWAY_XML}
  <Device Brand=\"${GW_BRAND}\" Model=\"${GW_MODEL}\" ${ID_ATTR}>
    <Gateway ${GW_ATTRS} />
  </Device>
"
    i=$((i + 1))
done

# -------------------------------------------------------
# Load devices from internal devices list
# -------------------------------------------------------
DEVICE_XML=""
if [ -f "$DEVICES_LIST_PATH" ]; then
    echo "Loading devices from internal list..."
    DEVICE_COUNT=$(jq '.devices | length' "$DEVICES_LIST_PATH" 2>/dev/null || echo 0)
    i=0
    while [ "$i" -lt "$DEVICE_COUNT" ]; do
        DEV_BRAND=$(jq -r ".devices[$i].brand"          "$DEVICES_LIST_PATH" 2>/dev/null || echo "null")
        DEV_MODEL=$(jq -r ".devices[$i].model"           "$DEVICES_LIST_PATH" 2>/dev/null || echo "null")
        DEV_SERIAL=$(jq -r ".devices[$i].serial_number"  "$DEVICES_LIST_PATH" 2>/dev/null || echo "null")

        IS_GATEWAY=0
        for gw in $CONFIGURED_GATEWAYS; do
            if [ "$gw" = "$DEV_SERIAL" ]; then
                IS_GATEWAY=1
                break
            fi
        done

        if [ "$IS_GATEWAY" -eq 1 ]; then
            i=$((i + 1))
            continue
        fi

        # Skip invalid entries
        if [ -z "$DEV_BRAND" ] || [ "$DEV_BRAND" = "null" ] || \
           [ -z "$DEV_MODEL" ] || [ "$DEV_MODEL" = "null" ] || \
           [ -z "$DEV_SERIAL" ] || [ "$DEV_SERIAL" = "null" ]; then
            i=$((i + 1))
            continue
        fi

        UNITS_XML=""
        UNIT_COUNT=$(jq ".devices[$i].units | length" "$DEVICES_LIST_PATH" 2>/dev/null || echo 0)
        j=0
        while [ "$j" -lt "$UNIT_COUNT" ]; do
            UNIT_ID=$(jq -r ".devices[$i].units[$j].unit_id"        "$DEVICES_LIST_PATH" 2>/dev/null || echo "null")
            UNIT_NAME=$(jq -r ".devices[$i].units[$j].endpoint_name" "$DEVICES_LIST_PATH" 2>/dev/null || echo "null")

            if [ -z "$UNIT_ID" ] || [ "$UNIT_ID" = "null" ]; then
                j=$((j + 1))
                continue
            fi

            EP_ATTR=""
            if [ -n "$UNIT_NAME" ] && [ "$UNIT_NAME" != "null" ]; then
                EP_ATTR=" Name=\"${UNIT_NAME}\""
            fi

            UNITS_XML="${UNITS_XML}
    <Unit Id=\"${UNIT_ID}\">
    </Unit>"
            j=$((j + 1))
        done

        DEVICE_XML="${DEVICE_XML}
  <Device Brand=\"${DEV_BRAND}\" Model=\"${DEV_MODEL}\" SerialNumber=\"${DEV_SERIAL}\">${UNITS_XML}
  </Device>
"
        i=$((i + 1))
    done
else
    echo "No devices list found. Devices will be discovered via MQTT."
    DEVICE_COUNT=0
fi

# -------------------------------------------------------
# Configure logging level based on debug_logging setting
# -------------------------------------------------------
LOG_LEVEL="Information"
if [ "$DEBUG_LOGGING" = "true" ]; then
    LOG_LEVEL="Debug"
fi

APPSETTINGS_PATH="/app/appsettings.json"
cat > "$APPSETTINGS_PATH" <<EOF
{
  "Logging": {
    "LogLevel": {
      "Default": "$LOG_LEVEL",
      "OpenNetty": "$LOG_LEVEL",
      "Microsoft": "$(if [ "$LOG_LEVEL" = "Debug" ]; then echo "Information"; else echo "Warning"; fi)"
    },
    "Console": {
      "FormatterName": "Simple",
      "FormatterOptions": {
        "SingleLine": true,
        "TimestampFormat": "yyyy-MM-dd HH:mm:ss "
      }
    }
  }
}
EOF

# -------------------------------------------------------
# Write the OpenNettyConfiguration.xml
# -------------------------------------------------------
cat > "$XML_PATH" <<EOF
<Configuration>

  <Mqtt ${MQTT_ATTRS} />
${GATEWAY_XML}${DEVICE_XML}
</Configuration>
EOF

echo "Generated OpenNettyConfiguration.xml:"
cat "$XML_PATH"
echo ""
echo "Configuration summary:"
echo "  MQTT Server: ${MQTT_SERVER}:${MQTT_PORT}"
echo "  Gateways configured: $GATEWAY_COUNT"
echo "  Devices in internal list: ${DEVICE_COUNT:-0}"
echo "  Debug logging: $(if [ "$DEBUG_LOGGING" = "true" ]; then echo "ENABLED"; else echo "disabled"; fi)"
echo ""
echo "Starting OpenNetty daemon (logging level: $LOG_LEVEL)..."

# Start the Python persistence script in the background
python3 /app/persist-devices.py &

# Run the daemon directly
exec /app/opennetty-daemon
