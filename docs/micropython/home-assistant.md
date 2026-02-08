# Home Assistant + ESP32 Integration

Control the fan and monitor the potentiometer from Home Assistant using MQTT.

## Architecture

```
ESP32 <--MQTT--> Mosquitto Broker <--MQTT--> Home Assistant
```

The ESP32 publishes sensor data and listens for fan commands over MQTT. Home Assistant discovers the devices automatically via [MQTT Discovery](https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery).

## Prerequisites

- ESP32 flashed with MicroPython (see [setup.md](setup.md))
- A machine to run Home Assistant (Raspberry Pi, old laptop, VM, etc.)
- All devices on the same local network

## 1. Install Home Assistant

Follow the official guide for your platform: [home-assistant.io/installation](https://www.home-assistant.io/installation/)

The simplest options:

| Method | Best for |
|--------|----------|
| **Home Assistant OS** | Dedicated Raspberry Pi or mini PC — full experience, easiest |
| **Docker container** | Running alongside other services on a Linux box |
| **Home Assistant Core** | Python venv install, most manual but lightest weight |

### Docker (quick start)

```sh
docker run -d \
  --name homeassistant \
  --restart=unless-stopped \
  -v /opt/homeassistant:/config \
  -e TZ=Australia/Sydney \
  --network=host \
  ghcr.io/home-assistant/home-assistant:stable
```

Open **http://\<your-ip\>:8123** and create an account.

## 2. Install Mosquitto MQTT Broker

Home Assistant needs an MQTT broker. Mosquitto is the standard choice.

### Option A: Mosquitto Add-on (Home Assistant OS / Supervised)

1. Go to **Settings → Add-ons → Add-on Store**
2. Search for **Mosquitto broker** and install it
3. Start the add-on
4. The broker is automatically configured for Home Assistant

### Option B: Standalone Mosquitto (Docker or bare metal)

```sh
# Arch Linux
sudo pacman -S mosquitto
sudo systemctl enable --now mosquitto

# Debian / Ubuntu
sudo apt install mosquitto mosquitto-clients
sudo systemctl enable --now mosquitto
```

Create a password file for authentication:

```sh
sudo mosquitto_passwd -c /etc/mosquitto/passwd homeassistant
```

Add to `/etc/mosquitto/mosquitto.conf`:

```
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd
```

Restart:

```sh
sudo systemctl restart mosquitto
```

Test it works:

```sh
# Terminal 1: subscribe
mosquitto_sub -h localhost -u homeassistant -P <password> -t "test/#"

# Terminal 2: publish
mosquitto_pub -h localhost -u homeassistant -P <password> -t "test/hello" -m "world"
```

## 3. Configure Home Assistant MQTT Integration

1. Go to **Settings → Devices & Services → Add Integration**
2. Search for **MQTT**
3. Enter the broker details:
   - **Broker**: `localhost` (if using the add-on) or the broker's IP
   - **Port**: `1883`
   - **Username**: `homeassistant`
   - **Password**: the password you set

Home Assistant will now listen for MQTT discovery messages.

## 4. Configure the ESP32

Add MQTT credentials to your `.env` file:

```
WIFI_SSID=your-wifi-name
WIFI_PASSWORD=your-wifi-password
MQTT_BROKER=192.168.1.100
MQTT_PORT=1883
MQTT_USER=homeassistant
MQTT_PASSWORD=your-mqtt-password
```

Replace `MQTT_BROKER` with the IP address of the machine running Mosquitto.

### Install umqtt on the board

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

### Upload and run

```sh
# Upload .env to the board
ampy --port /dev/ttyACM0 put .env

# Run the example
ampy --port /dev/ttyACM0 run examples/micropython/hello-home-assistant.py
```

You should see output like:

```
Already connected to your-wifi-name
  IP: 192.168.1.42
Connecting to MQTT broker 192.168.1.100:1883... OK
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
2. **Trigger**: State → Potentiometer → Above 75
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

## Troubleshooting

### ESP32 can't connect to MQTT

- Verify the broker IP is correct: `ping 192.168.1.100` from another machine
- Check Mosquitto is listening: `ss -tlnp | grep 1883`
- Test credentials: `mosquitto_pub -h <broker-ip> -u homeassistant -P <pass> -t test -m hi`
- If using a firewall, open port 1883: `sudo ufw allow 1883` or equivalent

### Devices don't appear in Home Assistant

- Make sure the MQTT integration is set up (Settings → Devices & Services)
- Check that discovery is enabled (it is by default)
- Monitor discovery topics: `mosquitto_sub -h localhost -u homeassistant -P <pass> -t "homeassistant/#"`
- Restart the ESP32 — it re-publishes discovery on startup

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
mosquitto_pub -h <broker> -u homeassistant -P <pass> \
  -t "venti/<device-id>/fan/set" -m "ON"

# Set speed to 50%
mosquitto_pub -h <broker> -u homeassistant -P <pass> \
  -t "venti/<device-id>/fan/speed/set" -m "50"
```

Find your device ID in the ESP32's serial output on startup.