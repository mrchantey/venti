# MicroPython Development with ESP32

Quick reference guide for developing MicroPython applications on ESP32 devices with the Venti project.

## TL;DR — Quickstart

Assuming you have Docker installed and an ESP32-S3 with MicroPython firmware:

```bash
# 1. Set up your PC (one-time)
./scripts/pc-setup.sh

# 2. Flash ESP32 with MicroPython (once per device)
./scripts/esp32-setup.sh

# 3. Run code on the device
./scripts/run.sh examples/micropython/blinky.py
```

Done! Your ESP32 is blinking.

## Prerequisites

| Requirement | Notes |
|------------|-------|
| **Python 3.8+** | Check with `python3 --version` |
| **ESP32-S3 board** | Connected via USB |
| **USB data cable** | Some cables are charge-only and won't work |
| **Docker** (optional) | Only needed for Home Assistant integration |
| **User permissions** | Add yourself to `uucp` (Arch) or `dialout` (Debian/Ubuntu) group |

### User Permissions Setup

On Linux, you need permission to access serial devices:

```bash
# Arch Linux
sudo usermod -a -G uucp $USER

# Debian/Ubuntu
sudo usermod -a -G dialout $USER

# Log out and back in for changes to take effect
```

## The Development Process

### 1. Set Up Your PC (One-Time Setup)

Run the PC setup script to install all development tools:

```bash
./scripts/pc-setup.sh
```

This creates a Python virtual environment (`.venv/`) and installs:
- `esptool` — for flashing firmware to ESP32
- `adafruit-ampy` — for transferring and running files
- `micropython-esp32-stubs` — for editor autocomplete
- `ruff` — Python linter
- All Venti project dependencies

**You only need to run this once** (or when dependencies change).

### 2. Flash Your ESP32 (Once Per Device)

Connect your ESP32 via USB and run:

```bash
./scripts/esp32-setup.sh
```

This script will:
1. Auto-detect your device on `/dev/ttyACM*` or `/dev/ttyUSB*`
2. Download MicroPython firmware (cached in `.firmware/`)
3. Erase the device's flash memory
4. Write the MicroPython firmware
5. Run `blinky.py` to verify everything works

**You only need to do this once per device** (or when updating firmware).

If the script can't connect to your device, try:
- Holding the **BOOT** button while connecting
- Unplugging and replugging the device
- Checking `dmesg | tail` for USB connection messages

### 3. Develop and Run Code

Write your MicroPython code in `examples/micropython/` or anywhere in the project, then run it:

```bash
# Run the default blinky example
./scripts/run.sh

# Run a specific script
./scripts/run.sh examples/micropython/hello-wifi.py

# Run your own code
./scripts/run.sh my_custom_script.py
```

The `run.sh` script:
- Auto-detects your device port
- Uploads your `.env` file (if it exists)
- Runs the specified script on the device

Press **Ctrl+C** to stop execution.

## Available Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `scripts/pc-setup.sh` | Install dev tools on your PC | Once, before everything else |
| `scripts/esp32-setup.sh` | Flash MicroPython to ESP32 | Once per new device |
| `scripts/run.sh` | Run code on ESP32 | Every time you want to test code |
| `scripts/home-assistant.sh` | Start Home Assistant + MQTT | When doing HA integration work |

## Project Structure

```
venti/
├── scripts/
│   ├── pc-setup.sh           # Set up PC environment
│   ├── esp32-setup.sh         # Flash ESP32 firmware
│   ├── run.sh                 # Run code on device
│   └── home-assistant.sh      # Start HA + MQTT via Docker
├── examples/micropython/
│   ├── blinky.py              # LED blink test
│   ├── hello-wifi.py          # WiFi connection example
│   ├── pot-fan.py             # Potentiometer + fan control
│   └── hello-home-assistant.py # MQTT + HA integration
├── docs/micropython/
│   ├── index.md               # This file
│   ├── setup.md               # Detailed setup reference
│   └── home-assistant.md      # Home Assistant integration guide
└── .venv/                     # Python virtual environment (created by pc-setup.sh)
```

## Example Workflow

Here's a typical development session:

```bash
# 1. First time setup (one-time)
./scripts/pc-setup.sh
./scripts/esp32-setup.sh

# 2. Create/edit your code
vim examples/micropython/my_project.py

# 3. Test it on the device
./scripts/run.sh examples/micropython/my_project.py

# 4. Iterate — edit and run again
./scripts/run.sh examples/micropython/my_project.py
```

## WiFi Configuration

Many examples need WiFi credentials. Create a `.env` file in the project root:

```bash
WIFI_SSID=your-network-name
WIFI_PASSWORD=your-wifi-password
MQTT_BROKER=192.168.1.100
MQTT_PORT=1883
MQTT_USER=
MQTT_PASSWORD=
```

The `run.sh` script automatically uploads this file to your device before running your code.

**Security note:** `.env` is in `.gitignore` — it won't be committed to version control.

## Interactive REPL

To interact with MicroPython directly on the device:

```bash
# Using screen (recommended)
screen /dev/ttyACM0 115200

# Or using Python's miniterm
python -m serial.tools.miniterm /dev/ttyACM0 115200
```

Useful REPL commands:
- **Ctrl+C** — stop the currently running program
- **Ctrl+D** — soft-reset the device
- **Ctrl+A then K** — exit screen

## Installing MicroPython Packages

Some examples require additional libraries. Install them via the REPL:

```bash
# Open REPL
screen /dev/ttyACM0 115200
```

Then in the MicroPython REPL:

```python
import mip
mip.install("umqtt.simple")  # MQTT library
```

Press **Ctrl+A then K** to exit.

## Editor Support

After running `pc-setup.sh`, your editor should autocomplete MicroPython imports like:

```python
from machine import Pin
import time
```

The setup script installs `micropython-esp32-stubs` which provides type information.

### For Zed Editor

Completely quit and restart Zed after running `pc-setup.sh`. The `.zed/settings.json` and `pyrightconfig.json` files configure autocomplete automatically.

### For Other Editors

Point your Python language server to the virtual environment at `.venv/`.

## Home Assistant Integration

To control your ESP32 from Home Assistant:

```bash
# 1. Start Home Assistant + Mosquitto MQTT broker
./scripts/home-assistant.sh

# 2. Configure MQTT in Home Assistant
#    (Open http://localhost:8123 and follow the prompts)

# 3. Update .env with your host IP (shown by the script)

# 4. Run the Home Assistant example
./scripts/run.sh examples/micropython/hello-home-assistant.py
```

The device will auto-discover in Home Assistant. See [home-assistant.md](home-assistant.md) for details.

## Troubleshooting

### "No device found"

- **Check USB cable** — must be a data cable, not charge-only
- **Check permissions** — are you in the `uucp` or `dialout` group?
- **List ports** — run `ls /dev/tty*` to see available devices
- **Check kernel logs** — run `dmesg | tail` after plugging in

### "esptool can't connect"

- **Hold BOOT button** while connecting (some boards require this)
- **Try a lower baud rate** — edit the script to use `--baud 115200`
- **Check the USB port** — try a different one

### "Import errors in editor"

- **Run pc-setup.sh** if you haven't already
- **Restart your editor completely** (quit and reopen, don't just reload)
- **Verify stubs** — run `source .venv/bin/activate && pip list | grep micropython`
- **Run validation** — `source .venv/bin/activate && python validate_setup.py`

### "Script runs but device doesn't respond"

- **Check the REPL** — use `screen /dev/ttyACM0 115200` to see errors
- **Verify imports** — make sure required packages are installed (see "Installing MicroPython Packages")
- **Check wiring** — if using hardware, verify connections match your code

### "Permission denied" on serial port

You're not in the right group. Run:

```bash
# Arch
sudo usermod -a -G uucp $USER

# Debian/Ubuntu
sudo usermod -a -G dialout $USER
```

Then **log out and back in** (not just a new terminal — a full logout).

## Next Steps

- **Read detailed setup docs**: [setup.md](setup.md)
- **Try the examples**: `ls examples/micropython/`
- **Set up Home Assistant**: [home-assistant.md](home-assistant.md)
- **Explore MicroPython docs**: https://docs.micropython.org/

## Reference

### MicroPython Resources

- [Official MicroPython Docs](https://docs.micropython.org/)
- [ESP32 Quick Reference](https://docs.micropython.org/en/latest/esp32/quickref.html)
- [MicroPython Forum](https://forum.micropython.org/)

### ESP32 Resources

- [ESP32-S3 Datasheet](https://www.espressif.com/en/products/socs/esp32-s3)
- [Espressif Documentation](https://docs.espressif.com/)

### Tools

- [esptool](https://github.com/espressif/esptool) — Flash firmware
- [ampy](https://github.com/scientifichackers/ampy) — File transfer
- [rshell](https://github.com/dhylands/rshell) — Alternative REPL shell