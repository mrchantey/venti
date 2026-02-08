# Expose a potentiometer sensor and fan to Home Assistant via MQTT
#
# Prerequisites:
#   - MQTT broker running (e.g. Mosquitto) accessible from the ESP32
#   - Home Assistant configured with MQTT integration
#   - .env uploaded to the board with WiFi and MQTT credentials
#
# Upload .env and install umqtt, then run:
# ```sh
# ampy --port /dev/ttyACM0 put .env
# ampy --port /dev/ttyACM0 run examples/micropython/hello-home-assistant.py
# ```
#
# .env format:
#   WIFI_SSID=my-ssid
#   WIFI_PASSWORD=my-password
#   MQTT_BROKER=192.168.1.100
#   MQTT_PORT=1883
#   MQTT_USER=homeassistant
#   MQTT_PASSWORD=mqtt-password
import json
import time

import network
from machine import ADC, PWM, Pin, unique_id
from ubinascii import hexlify
from umqtt.simple import MQTTClient

# --- Hardware setup (matches pot-fan.py) ---
# GPIO6 potentiometer input
pot = ADC(Pin(6))
# GPIO7 PWM pin for fan
pwm_pin = PWM(Pin(7))
pwm_pin.freq(1000)

# --- Device identity ---
DEVICE_ID = hexlify(unique_id()).decode()
DEVICE_NAME = "venti-esp32"

# --- MQTT topics ---
POT_STATE_TOPIC = f"venti/{DEVICE_ID}/pot/state"
FAN_STATE_TOPIC = f"venti/{DEVICE_ID}/fan/state"
FAN_COMMAND_TOPIC = f"venti/{DEVICE_ID}/fan/set"
FAN_SPEED_STATE_TOPIC = f"venti/{DEVICE_ID}/fan/speed/state"
FAN_SPEED_COMMAND_TOPIC = f"venti/{DEVICE_ID}/fan/speed/set"
AVAILABILITY_TOPIC = f"venti/{DEVICE_ID}/availability"

# Home Assistant MQTT discovery prefix
HA_DISCOVERY_PREFIX = "homeassistant"

# --- Fan state ---
fan_on = False
fan_speed = 0  # 0-100 percentage


def load_env(path=".env"):
    """Parse a .env file from the board's filesystem into a dict."""
    env = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                key, value = line.split("=", 1)
                env[key.strip()] = value.strip()
    except OSError:
        print(f"ERROR: could not open {path}")
        print("Upload it first:  ampy --port /dev/ttyACM0 put .env")
        raise SystemExit
    return env


def connect_wifi(ssid, password, timeout_s=15):
    """Connect to a WiFi network and return the WLAN interface."""
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)

    if wlan.isconnected():
        print(f"Already connected to {ssid}")
        print(f"  IP: {wlan.ifconfig()[0]}")
        return wlan

    print(f"Connecting to '{ssid}'...", end="")
    wlan.connect(ssid, password)

    start = time.time()
    while not wlan.isconnected():
        if time.time() - start > timeout_s:
            print(" FAILED")
            print(f"Could not connect to '{ssid}' within {timeout_s}s")
            raise SystemExit
        print(".", end="")
        time.sleep(1)

    print(" OK")
    print(f"  IP: {wlan.ifconfig()[0]}")
    return wlan


def connect_mqtt(broker, port, user, password):
    """Connect to the MQTT broker and return the client."""
    client = MQTTClient(
        DEVICE_ID,
        broker,
        port=port,
        user=user,
        password=password,
        keepalive=60,
    )
    client.set_last_will(AVAILABILITY_TOPIC, "offline", retain=True)
    client.set_callback(on_mqtt_message)

    print(f"Connecting to MQTT broker {broker}:{port}...", end="")
    client.connect()
    print(" OK")

    return client


def on_mqtt_message(topic, msg):
    """Handle incoming MQTT messages (fan commands from Home Assistant)."""
    global fan_on, fan_speed

    topic = topic.decode()
    msg = msg.decode()

    print(f"  MQTT << {topic}: {msg}")

    if topic == FAN_COMMAND_TOPIC:
        fan_on = msg == "ON"
        apply_fan()

    elif topic == FAN_SPEED_COMMAND_TOPIC:
        try:
            fan_speed = max(0, min(100, int(msg)))
        except ValueError:
            print(f"  Invalid speed value: {msg}")
            return
        apply_fan()


def apply_fan():
    """Set PWM duty cycle based on current fan state and speed."""
    if fan_on and fan_speed > 0:
        # Map 0-100 percentage to 0-1023 duty cycle
        duty = int(fan_speed * 1023 / 100)
    else:
        duty = 0

    pwm_pin.duty(duty)
    print(f"  Fan: {'ON' if fan_on else 'OFF'}, speed={fan_speed}%, duty={duty}")


def publish_ha_discovery(client):
    """Publish MQTT discovery messages so Home Assistant auto-detects our entities."""
    device_info = {
        "identifiers": [DEVICE_ID],
        "name": DEVICE_NAME,
        "model": "ESP32-S3",
        "manufacturer": "Venti",
    }

    # --- Potentiometer sensor ---
    pot_config = {
        "name": "Potentiometer",
        "unique_id": f"{DEVICE_ID}_pot",
        "state_topic": POT_STATE_TOPIC,
        "unit_of_measurement": "%",
        "icon": "mdi:knob",
        "availability_topic": AVAILABILITY_TOPIC,
        "device": device_info,
    }
    pot_discovery_topic = f"{HA_DISCOVERY_PREFIX}/sensor/{DEVICE_ID}/pot/config"
    client.publish(pot_discovery_topic, json.dumps(pot_config), retain=True)
    print(f"  Discovery >> {pot_discovery_topic}")

    # --- Fan ---
    fan_config = {
        "name": "Fan",
        "unique_id": f"{DEVICE_ID}_fan",
        "state_topic": FAN_STATE_TOPIC,
        "command_topic": FAN_COMMAND_TOPIC,
        "percentage_state_topic": FAN_SPEED_STATE_TOPIC,
        "percentage_command_topic": FAN_SPEED_COMMAND_TOPIC,
        "availability_topic": AVAILABILITY_TOPIC,
        "speed_range_min": 1,
        "speed_range_max": 100,
        "device": device_info,
    }
    fan_discovery_topic = f"{HA_DISCOVERY_PREFIX}/fan/{DEVICE_ID}/fan/config"
    client.publish(fan_discovery_topic, json.dumps(fan_config), retain=True)
    print(f"  Discovery >> {fan_discovery_topic}")


def publish_state(client):
    """Publish current pot and fan state to MQTT."""
    # Read pot as percentage (0-100)
    pot_raw = pot.read_u16()
    pot_pct = int(pot_raw * 100 / 65535)

    client.publish(POT_STATE_TOPIC, str(pot_pct))
    client.publish(FAN_STATE_TOPIC, "ON" if fan_on else "OFF")
    client.publish(FAN_SPEED_STATE_TOPIC, str(fan_speed))


def main():
    env = load_env()

    # --- Validate config ---
    ssid = env.get("WIFI_SSID")
    wifi_pass = env.get("WIFI_PASSWORD")
    if not ssid or not wifi_pass:
        print("ERROR: .env must contain WIFI_SSID and WIFI_PASSWORD")
        raise SystemExit

    mqtt_broker = env.get("MQTT_BROKER")
    if not mqtt_broker:
        print("ERROR: .env must contain MQTT_BROKER")
        raise SystemExit

    mqtt_port = int(env.get("MQTT_PORT", "1883"))
    mqtt_user = env.get("MQTT_USER", "")
    mqtt_pass = env.get("MQTT_PASSWORD", "")

    # --- Connect ---
    connect_wifi(ssid, wifi_pass)
    client = connect_mqtt(mqtt_broker, mqtt_port, mqtt_user, mqtt_pass)

    # Subscribe to fan commands
    client.subscribe(FAN_COMMAND_TOPIC)
    client.subscribe(FAN_SPEED_COMMAND_TOPIC)
    print(f"  Subscribed to {FAN_COMMAND_TOPIC}")
    print(f"  Subscribed to {FAN_SPEED_COMMAND_TOPIC}")

    # Publish HA auto-discovery config
    print("Publishing Home Assistant discovery configs...")
    publish_ha_discovery(client)

    # Mark device as online
    client.publish(AVAILABILITY_TOPIC, "online", retain=True)
    print(f"\nDevice {DEVICE_NAME} ({DEVICE_ID}) is online")
    print("Streaming pot readings and listening for fan commands...\n")

    # --- Main loop ---
    last_publish = 0
    while True:
        # Check for incoming MQTT messages (non-blocking)
        client.check_msg()

        now = time.time()
        if now - last_publish >= 1:
            publish_state(client)
            last_publish = now

            pot_raw = pot.read_u16()
            pot_pct = int(pot_raw * 100 / 65535)
            print(f"  pot={pot_pct}%  fan={'ON' if fan_on else 'OFF'}@{fan_speed}%")

        time.sleep(0.1)


main()
