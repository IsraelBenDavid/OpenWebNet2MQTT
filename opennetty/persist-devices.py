#!/usr/bin/env python3
"""
OpenNetty Device Persistence Service

Monitors MQTT discovery topics and persists discovered devices to /data/devices.json
This ensures devices remain available across daemon restarts.
"""

import json
import re
import sys
import time
from pathlib import Path
from typing import Dict, Set

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("ERROR: paho-mqtt not installed. Install with: pip install paho-mqtt")
    sys.exit(1)

CONFIG_PATH = Path("/data/options.json")
DEVICES_LIST_PATH = Path("/data/devices.json")

class DevicePersistence:
    def __init__(self):
        self.discovered_devices: Dict = {"devices": []}
        self.device_serials: Set[str] = set()
        self.mqtt_client = None
        self.load_devices()

    def load_devices(self):
        """Load existing devices from /data/devices.json"""
        
        # Add configured gateways to the set so they are ignored by discovery
        try:
            if CONFIG_PATH.exists():
                with open(CONFIG_PATH) as f:
                    config = json.load(f)
                    for gw in config.get("gateways", []):
                        serial = gw.get("serial_number")
                        if serial:
                            self.device_serials.add(serial.lower())
        except Exception as e:
            print(f"⚠ Error loading gateways from config: {e}")

        if DEVICES_LIST_PATH.exists():
            try:
                with open(DEVICES_LIST_PATH) as f:
                    self.discovered_devices = json.load(f)
                    for device in self.discovered_devices.get("devices", []):
                        self.device_serials.add(device.get("serial_number", "").lower())
                    print(f"✓ Loaded {len(self.discovered_devices['devices'])} devices from {DEVICES_LIST_PATH}")
            except Exception as e:
                print(f"⚠ Error loading devices: {e}")
                self.discovered_devices = {"devices": []}
        else:
            print(f"✓ No existing devices file, starting fresh")
            self.save_devices()

    def save_devices(self, new_device_info=None):
        """
        Save discovered devices to /data/devices.json.
        Reads fresh from disk first to avoid overwriting changes made by the C# daemon.
        """
        latest_data = {"devices": []}
        
        if DEVICES_LIST_PATH.exists():
            try:
                with open(DEVICES_LIST_PATH, 'r') as f:
                    latest_data = json.load(f)
            except Exception as e:
                print(f"⚠ Error reading existing devices: {e}")
                latest_data = self.discovered_devices
        else:
            latest_data = self.discovered_devices

        if new_device_info:
            new_serial = new_device_info.get("serial_number", "").lower()
            
            # Prevent duplicates by checking if the serial already exists in the file
            exists = False
            for d in latest_data.get("devices", []):
                if d.get("serial_number", "").lower() == new_serial:
                    exists = True
                    break
                    
            if not exists:
                latest_data["devices"].append(new_device_info)
            
        try:
            with open(DEVICES_LIST_PATH, 'w') as f:
                json.dump(latest_data, f, indent=2)
            print(f"✓ Saved {len(latest_data.get('devices', []))} devices to {DEVICES_LIST_PATH}")
            self.discovered_devices = latest_data
        except Exception as e:
            print(f"✗ Error saving devices: {e}")

    def extract_device_from_discovery(self, payload_str: str) -> dict:
        """Extract device info from Home Assistant discovery payload"""
        try:
            payload = json.loads(payload_str)
            device_info = payload.get("device", {})

            if not device_info:
                return None

            serial = device_info.get("serial_number")
            if not serial:
                return None

            # Extract unit IDs from discovery components (light/switch entities
            # have topics like "zigbee/<serial>/<unit_id>/switch_state/set")
            units = []
            seen_unit_ids = set()
            components = payload.get("components", {})
            for comp in components.values():
                if not isinstance(comp, dict):
                    continue
                # Look for command topics that contain a unit ID segment
                cmd_topic = comp.get("command_topic", "")
                parts = cmd_topic.split("/")
                # Expected format: opennetty/zigbee/<serial>/<unit_id>/<attr>/set
                if len(parts) >= 5:
                    try:
                        unit_id = int(parts[3])
                        if unit_id > 0 and unit_id not in seen_unit_ids:
                            seen_unit_ids.add(unit_id)
                            units.append({"unit_id": unit_id})
                    except (ValueError, IndexError):
                        pass

            # Use 'model_id' to get the raw hardware identifier required by OpenNetty's core
            return {
                "brand": device_info.get("manufacturer", "Unknown"),
                "model": device_info.get("model_id", "Unknown"),
                "serial_number": serial,
                "units": units
            }
        except Exception as e:
            print(f"⚠ Error parsing discovery payload: {e}")
            return None

    def on_message(self, client, userdata, msg):
        """Handle incoming MQTT messages"""
        try:
            # Match homeassistant/device/opennetty-*/config topics
            # Topic format: homeassistant/device/opennetty-<name>/<serial>/config
            match = re.match(r"homeassistant/device/opennetty-[^/]+/([^/]+)/config", msg.topic)
            if not match:
                return

            serial = match.group(1).lower()

            # Skip if already have this device
            if serial in self.device_serials:
                return

            device_info = self.extract_device_from_discovery(msg.payload.decode())
            if not device_info:
                return

            # Add to our list
            print(f"✓ Discovered device: {device_info['brand']} {device_info['model']} ({serial})")
            self.device_serials.add(serial)
            self.save_devices(device_info)

        except Exception as e:
            print(f"✗ Error processing message: {e}")

    def on_connect(self, client, userdata, connect_flags, reason_code, properties):
        """Handle MQTT connection"""
        if reason_code == 0:
            print("✓ Connected to MQTT broker")
            
            # Subscribe to the parent device topic
            # The regex in on_message will filter the specific opennetty topics
            client.subscribe("homeassistant/device/#")
            
            print("✓ Subscribed to discovery topics")
        else:
            print(f"✗ MQTT connection failed: {reason_code}")

    def on_disconnect(self, client, userdata, disconnect_flags, reason_code, properties):
        """Handle MQTT disconnection"""
        if reason_code == 0:
            print("✓ Disconnected from MQTT broker")
        else:
            print(f"⚠ Unexpected MQTT disconnection: {reason_code}, will reconnect...")

    def connect_mqtt(self):
        """Connect to MQTT broker"""
        try:
            with open(CONFIG_PATH) as f:
                config = json.load(f)

            mqtt_server = config.get("mqtt_server")
            mqtt_port = config.get("mqtt_port", 1883)
            mqtt_username = config.get("mqtt_username", "")
            mqtt_password = config.get("mqtt_password", "")

            if not mqtt_server:
                print("✗ MQTT server not configured")
                return False

            self.mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
            self.mqtt_client.on_message = self.on_message
            self.mqtt_client.on_connect = self.on_connect
            self.mqtt_client.on_disconnect = self.on_disconnect

            if mqtt_username:
                self.mqtt_client.username_pw_set(mqtt_username, mqtt_password)

            print(f"Connecting to MQTT: {mqtt_server}:{mqtt_port}...")
            self.mqtt_client.connect(mqtt_server, mqtt_port, keepalive=60)
            self.mqtt_client.loop_start()
            return True

        except Exception as e:
            print(f"✗ Error connecting to MQTT: {e}")
            return False

    def run(self):
        """Start the persistence service"""
        print("=" * 60)
        print("OpenNetty Device Persistence Service")
        print("=" * 60)
        print()

        if not self.connect_mqtt():
            print("✗ Failed to connect to MQTT. Retrying...")
            time.sleep(5)
            return self.run()

        print()
        print("✓ Service running. Monitoring for discovered devices...")
        print("  Press Ctrl+C to stop")
        print()

        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n✓ Shutting down...")
            if self.mqtt_client:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
            print("✓ Device Persistence Service stopped")

if __name__ == "__main__":
    service = DevicePersistence()
    service.run()
