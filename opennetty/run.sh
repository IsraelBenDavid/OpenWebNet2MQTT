#!/bin/sh
set -eu

CONFIG_PATH="/data/options.json"
DISCOVERED_DEVICES_PATH="/data/discovered-devices.json"
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
GATEWAY_COUNT=$(jq '.gateways | length' "$CONFIG_PATH")
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
# Build <Device> nodes for user-configured devices
# -------------------------------------------------------
DEVICE_XML=""
DEVICE_COUNT=$(jq '.devices | length' "$CONFIG_PATH")
i=0
while [ "$i" -lt "$DEVICE_COUNT" ]; do
    DEV_BRAND=$(jq -r ".devices[$i].brand"          "$CONFIG_PATH")
    DEV_MODEL=$(jq -r ".devices[$i].model"           "$CONFIG_PATH")
    DEV_SERIAL=$(jq -r ".devices[$i].serial_number"  "$CONFIG_PATH")

    # Skip entries with empty required fields
    if [ -z "$DEV_BRAND" ] || [ "$DEV_BRAND" = "null" ] || \
       [ -z "$DEV_MODEL" ] || [ "$DEV_MODEL" = "null" ] || \
       [ -z "$DEV_SERIAL" ] || [ "$DEV_SERIAL" = "null" ]; then
        i=$((i + 1))
        continue
    fi

    UNITS_XML=""
    UNIT_COUNT=$(jq ".devices[$i].units | length" "$CONFIG_PATH")
    j=0
    while [ "$j" -lt "$UNIT_COUNT" ]; do
        UNIT_ID=$(jq -r ".devices[$i].units[$j].unit_id"        "$CONFIG_PATH")
        UNIT_NAME=$(jq -r ".devices[$i].units[$j].endpoint_name" "$CONFIG_PATH")

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
      <Endpoint${EP_ATTR} />
    </Unit>"
        j=$((j + 1))
    done

    DEVICE_XML="${DEVICE_XML}
  <Device Brand=\"${DEV_BRAND}\" Model=\"${DEV_MODEL}\" SerialNumber=\"${DEV_SERIAL}\">${UNITS_XML}
  </Device>
"
    i=$((i + 1))
done

# -------------------------------------------------------
# Merge discovered devices from previous scans
# -------------------------------------------------------
DISCOVERED_DEVICE_XML=""
if [ -f "$DISCOVERED_DEVICES_PATH" ]; then
    echo "Found discovered devices file, merging..."
    DISCOVERED_COUNT=$(jq '.devices | length' "$DISCOVERED_DEVICES_PATH" 2>/dev/null || echo 0)
    i=0
    while [ "$i" -lt "$DISCOVERED_COUNT" ]; do
        DISC_BRAND=$(jq -r ".devices[$i].brand"          "$DISCOVERED_DEVICES_PATH" 2>/dev/null || echo "null")
        DISC_MODEL=$(jq -r ".devices[$i].model"           "$DISCOVERED_DEVICES_PATH" 2>/dev/null || echo "null")
        DISC_SERIAL=$(jq -r ".devices[$i].serial_number"  "$DISCOVERED_DEVICES_PATH" 2>/dev/null || echo "null")

        # Skip invalid entries
        if [ -z "$DISC_BRAND" ] || [ "$DISC_BRAND" = "null" ] || \
           [ -z "$DISC_MODEL" ] || [ "$DISC_MODEL" = "null" ] || \
           [ -z "$DISC_SERIAL" ] || [ "$DISC_SERIAL" = "null" ]; then
            i=$((i + 1))
            continue
        fi

        # Check if this device already exists in user config (avoid duplicates)
        ALREADY_CONFIGURED=$(echo "$DEVICE_XML" | grep -c "SerialNumber=\"${DISC_SERIAL}\"" || echo 0)
        if [ "$ALREADY_CONFIGURED" -gt 0 ]; then
            echo "Skipping discovered device ${DISC_SERIAL} (already configured)"
            i=$((i + 1))
            continue
        fi

        DISC_UNITS_XML=""
        DISC_UNIT_COUNT=$(jq ".devices[$i].units | length" "$DISCOVERED_DEVICES_PATH" 2>/dev/null || echo 0)
        j=0
        while [ "$j" -lt "$DISC_UNIT_COUNT" ]; do
            DISC_UNIT_ID=$(jq -r ".devices[$i].units[$j].unit_id"        "$DISCOVERED_DEVICES_PATH" 2>/dev/null || echo "null")
            DISC_UNIT_NAME=$(jq -r ".devices[$i].units[$j].endpoint_name" "$DISCOVERED_DEVICES_PATH" 2>/dev/null || echo "null")

            if [ -z "$DISC_UNIT_ID" ] || [ "$DISC_UNIT_ID" = "null" ]; then
                j=$((j + 1))
                continue
            fi

            DISC_EP_ATTR=""
            if [ -n "$DISC_UNIT_NAME" ] && [ "$DISC_UNIT_NAME" != "null" ]; then
                DISC_EP_ATTR=" Name=\"${DISC_UNIT_NAME}\""
            fi

            DISC_UNITS_XML="${DISC_UNITS_XML}
    <Unit Id=\"${DISC_UNIT_ID}\">
      <Endpoint${DISC_EP_ATTR} />
    </Unit>"
            j=$((j + 1))
        done

        DISCOVERED_DEVICE_XML="${DISCOVERED_DEVICE_XML}
  <Device Brand=\"${DISC_BRAND}\" Model=\"${DISC_MODEL}\" SerialNumber=\"${DISC_SERIAL}\">${DISC_UNITS_XML}
  </Device>
"
        i=$((i + 1))
    done
else
    echo "No discovered devices file found (first run)"
fi

# -------------------------------------------------------
# Write the OpenNettyConfiguration.xml
# -------------------------------------------------------
cat > "$XML_PATH" <<EOF
<Configuration>

  <Mqtt ${MQTT_ATTRS} />
${GATEWAY_XML}${DEVICE_XML}${DISCOVERED_DEVICE_XML}
</Configuration>
EOF

echo "Generated OpenNettyConfiguration.xml:"
cat "$XML_PATH"
echo ""
echo "Configuration summary:"
echo "  MQTT Server: ${MQTT_SERVER}:${MQTT_PORT}"
echo "  Gateways configured: $GATEWAY_COUNT"
echo "  Devices configured: $DEVICE_COUNT"
echo "  Devices discovered: ${DISCOVERED_COUNT:-0}"
echo ""
echo "Starting OpenNetty daemon..."

# Run the daemon (exec replaces the shell so signals propagate correctly)
exec /app/opennetty-daemon
