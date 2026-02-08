# Home Assistant + ESP32 Integration

Control the fan and monitor the potentiometer from Home Assistant using MQTT.

## Architecture

```
ESP32 <--MQTT--> Mosquitto (Docker) <--MQTT--> Home Assistant (Docker)
```

The ESP32 publishes sensor data and listens for fan commands over MQTT. Home Assistant discovers the devices automatically via [MQTT Discovery](https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery).

Both Home Assistant and Mosquitto run as Docker containers on your dev machine using `--network=host`, so they share the host's network stack and can talk to each other (and the ESP32) without any port-mapping gymnastics.

> **Note:** The Docker version of Home Assistant does not support Add-ons (like the Mosquitto add-on). That feature is exclusive to Home Assistant OS and Supervised installs. This guide runs Mosquitto as a separate Docker container instead.

## Prerequisites

- ESP32 flashed with MicroPython (see [setup.md](setup.md))
- Docker installed on your dev machine
- All devices on the same local network

## Quick Start

A single script handles everything:

```sh
./home-assistant.sh          # Start Home Assistant + Mosquitto
./home-assistant.sh stop     # Tear down containers
./home-assistant.sh status   # Check container health
./home-assistant.sh test     # Verify MQTT pub/sub works
```

### What the script does

1. Stops and removes any existing `homeassistant` / `mosquitto` containers
2. Creates a Mosquitto config at `/opt/mosquitto/config/mosquitto.conf` (anonymous access, persistence enabled)
3. Starts Mosquitto via `eclipse-mosquitto:2` with `--network=host`
4. Starts Home Assistant via `ghcr.io/home-assistant/home-assistant:stable` with `--network=host`
5. Waits for both services to be ready
6. Runs a quick MQTT sanity check
7. Prints your host IP and next steps

## Step-by-Step Setup

### 1. Run the script

```sh
./home-assistant.sh
```

You'll see output like:

```
======================================
  🌬️  Venti — Home Assistant Setup
======================================

✓ Mosquitto is listening on port 1883
✓ Home Assistant is ready
✓ MQTT broker accepts messages

======================================
  ✅  Everything is running
======================================

  Home Assistant:  http://localhost:8123
                   http://192.168.86.220:8123
  MQTT Broker:     192.168.86.220:1883
```

### 2. Create a Home Assistant account

Open **http://localhost:8123** in your browser. On first launch you'll be walked through onboarding — create a user account and pick your location/units.

### 3. Add the MQTT integration

1. Go to **Settings → Devices & Services → Add Integration**
2. Search for **MQTT**
3. Enter the broker details:
   - **Broker**: `localhost`
   - **Port**: `1883`
   - **Username**: *(leave blank)*
   - **Password**: *(leave blank)*
4. Click **Submit**

Home Assistant will now listen for MQTT discovery messages.

### 4. Configure the ESP32

Add MQTT credentials to your `.env` file (the script prints your host IP):

```
WIFI_SSID=your-wifi-name
WIFI_PASSWORD=your-wifi-password
MQTT_BROKER=192.168.86.220
MQTT_PORT=1883
MQTT_USER=
MQTT_PASSWORD=
```

Replace `MQTT_BROKER` with the IP address shown in the script output.

> Mosquitto is configured with `allow_anonymous true`, so credentials are optional. If you set `MQTT_USER` / `MQTT_PASSWORD` in `.env`, the broker will still accept the connection — it just ignores the credentials.

### 5. Install umqtt on the board

The `umqtt.simple` library is needed for MQTT. Install it via the MicroPython REPL:

```sh
# Open a REPL session
screen /dev/ttyACM0 115200
```

Then in the REPL:

```python
import mip
mip.install("umqtt.simple")
```

Press `Ctrl-A` then `K` to exit screen.

### 6. Upload and run

```sh
# Upload .env to the board
ampy --port /dev/ttyACM0 put .env

# Run the example
./run.sh examples/micropython/hello-home-assistant.py
```

You should see output like:

```
Already connected to your-wifi-name
  IP: 192.168.86.42
Connecting to MQTT broker 192.168.86.220:1883... OK
Publishing Home Assistant discovery configs...
  Discovery >> homeassistant/sensor/.../pot/config
  Discovery >> homeassistant/fan/.../fan/config

Device venti-esp32 (...) is online
Streaming pot readings and listening for fan commands...

  pot=42%  fan=OFF@0%
  pot=43%  fan=OFF@0%
```

## 5. Use It in Home Assistant

Once the ESP32 is running, Home Assistant auto-discovers two entities:

| Entity | Type | Description |
|--------|------|-------------|
| **Potentiometer** | Sensor | Current pot position as a percentage (0–100%) |
| **Fan** | Fan | On/off toggle and speed control (0–100%) |

### Find your devices

1. Go to **Settings → Devices & Services → MQTT**
2. Click on the **venti-esp32** device
3. You'll see the potentiometer sensor and fan control

### Add to a dashboard

1. Go to **Overview → Edit Dashboard** (pencil icon)
2. Click **Add Card**
3. Search for your entities:
   - **Gauge card** for the potentiometer — shows the current value as a dial
   - **Tile card** for the fan — gives you on/off and speed slider
4. Save

### Create automations

Example: turn on the fan when the pot goes above 75%.

1. Go to **Settings → Automations & Scenes → Create Automation**
2. **Trigger**: Numeric state → Potentiometer → Above 75
3. **Action**: Call service → `fan.turn_on` → target the fan entity, set percentage to pot value
4. Save

Or in YAML (`automations.yaml`):

```yaml
- alias: "Pot controls fan"
  trigger:
    - platform: numeric_state
      entity_id: sensor.venti_esp32_potentiometer
      above: 75
  action:
    - service: fan.turn_on
      target:
        entity_id: fan.venti_esp32_fan
      data:
        percentage: "{{ states('sensor.venti_esp32_potentiometer') | int }}"
```

## Managing the Services

### Check status

```sh
./home-assistant.sh status
```

### Stop everything

```sh
./home-assistant.sh stop
```

### Test MQTT independently

```sh
# Via the script
./home-assistant.sh test

# Or manually using mosquitto tools inside the container
docker exec mosquitto mosquitto_sub -h localhost -t "venti/#" -v

# In another terminal, publish a test message
docker exec mosquitto mosquitto_pub -h localhost -t "venti/test" -m "hello"
```

### View logs

```sh
docker logs -f mosquitto       # Mosquitto logs
docker logs -f homeassistant   # Home Assistant logs
```

### Data persistence

| Service | Config/data location |
|---------|---------------------|
| Home Assistant | `/opt/homeassistant` |
| Mosquitto config | `/opt/mosquitto/config/mosquitto.conf` |
| Mosquitto data | `/opt/mosquitto/data` |

These directories persist across container restarts. To start completely fresh, stop the containers and delete these directories.

## Troubleshooting

### ESP32 can't connect to MQTT

- Verify the broker IP is correct — use the IP printed by `./home-assistant.sh`, not `localhost`
- Check Mosquitto is listening: `ss -tlnp | grep 1883`
- Test from the host: `docker exec mosquitto mosquitto_pub -h localhost -t test -m hi`
- Make sure the ESP32 and your machine are on the same WiFi network

### Devices don't appear in Home Assistant

- Make sure the MQTT integration is added (Settings → Devices & Services)
- Check that discovery is enabled (it is by default)
- Monitor discovery topics: `docker exec mosquitto mosquitto_sub -h localhost -t "homeassistant/#" -v`
- Restart the ESP32 — it re-publishes discovery on startup

### Home Assistant shows "Add-ons" missing

This is expected — the Docker installation of Home Assistant does not support Add-ons. That's why this guide runs Mosquitto as a separate Docker container. You don't need Add-ons for this setup.

### Stale entities after reflashing

Home Assistant caches discovered devices. To clean up:

1. Go to **Settings → Devices & Services → MQTT**
2. Find the old device and delete it
3. Restart the ESP32 to re-publish discovery

### Fan doesn't respond

- Check the ESP32 serial output for incoming MQTT messages
- Verify the PWM wiring (GPIO7 → fan driver)
- Test with a direct MQTT publish:

```sh
# Turn fan on
docker exec mosquitto mosquitto_pub \
  -h localhost -t "venti/<device-id>/fan/set" -m "ON"

# Set speed to 50%
docker exec mosquitto mosquitto_pub \
  -h localhost -t "venti/<device-id>/fan/speed/set" -m "50"
```

Find your device ID in the ESP32's serial output on startup.

### Port conflicts

If port 1883 or 8123 is already in use, stop the conflicting service or edit the port variables at the top of `home-assistant.sh`.