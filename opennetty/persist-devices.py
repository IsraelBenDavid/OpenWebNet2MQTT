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
        if DEVICES_LIST_PATH.exists():
            try:
                with open(DEVICES_LIST_PATH) as f:
                    self.discovered_devices = json.load(f)
                    for device in self.discovered_devices.get("devices", []):
                        self.device_serials.add(device.get("serial_number", ""))
                    print(f"✓ Loaded {len(self.discovered_devices['devices'])} devices from {DEVICES_LIST_PATH}")
            except Exception as e:
                print(f"⚠ Error loading devices: {e}")
                self.discovered_devices = {"devices": []}
        else:
            print(f"✓ No existing devices file, starting fresh")
            self.save_devices()

    def save_devices(self):
        """Save discovered devices to /data/devices.json"""
        try:
            with open(DEVICES_LIST_PATH, 'w') as f:
                json.dump(self.discovered_devices, f, indent=2)
            print(f"✓ Saved {len(self.discovered_devices['devices'])} devices to {DEVICES_LIST_PATH}")
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

            return {
                "brand": device_info.get("manufacturer", "Unknown"),
                "model": device_info.get("model_id", "Unknown"),
                "serial_number": serial,
                "units": []  # Will be populated from components
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
            self.discovered_devices["devices"].append(device_info)
            self.device_serials.add(serial)
            self.save_devices()

        except Exception as e:
            print(f"✗ Error processing message: {e}")

    def on_connect(self, client, userdata, connect_flags, reason_code, properties):
        """Handle MQTT connection"""
        if reason_code.is_success:
            print("✓ Connected to MQTT broker")
            # Subscribe to Home Assistant discovery topics
            # Use # wildcard to match any depth
            client.subscribe("homeassistant/device/opennetty-#")
            print("✓ Subscribed to discovery topics")
        else:
            print(f"✗ MQTT connection failed: {reason_code}")

    def on_disconnect(self, client, userdata, disconnect_flags, reason_code, properties):
        """Handle MQTT disconnection"""
        if reason_code.is_success:
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
