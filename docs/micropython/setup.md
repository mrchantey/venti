# MicroPython Setup — Detailed Reference

This guide covers everything needed to develop and deploy MicroPython code to an ESP32-S3 board.

> **Quick Start?** See [index.md](index.md) for a streamlined quickstart guide.

## Prerequisites

- Python 3.8+ installed
- ESP32-S3 board connected via USB
- On Arch Linux: your user must be in the `uucp` group (other distros: `dialout` group)

```bash
# Arch Linux
sudo usermod -a -G uucp $USER

# Debian/Ubuntu
sudo usermod -a -G dialout $USER

# Log out and back in for group changes to take effect
```

## Quick Start

The setup process is split into two scripts:

```bash
# 1. Set up your PC (one-time)
./scripts/pc-setup.sh

# 2. Flash your ESP32 device (once per device)
./scripts/esp32-setup.sh
```

### PC Setup (`pc-setup.sh`)

This script sets up your development environment:

1. Creates a Python virtual environment (`.venv/`)
2. Installs all dependencies (stubs, esptool, ampy, dev tools)

**Run this once** before doing any ESP32 development.

### ESP32 Setup (`esp32-setup.sh`)

This script flashes MicroPython firmware to your device:

1. Detects your ESP32-S3's serial port
2. Downloads MicroPython firmware (if not already cached)
3. Erases the board's flash
4. Writes the MicroPython firmware
5. Runs `blinky.py` to verify the setup

**Run this once per device** (or when updating firmware).

## Running Code

Once setup is complete, use `scripts/run.sh` to deploy and run code on the device:

```bash
# Run the default blinky example
./scripts/run.sh

# Run a specific script
./scripts/run.sh examples/micropython/my_script.py
```

The run script auto-detects the serial port each time and uploads your `.env` file if present.

## What Gets Installed

All tools are installed into the `.venv/` virtual environment — nothing is installed globally.

| Package | Purpose |
|---------|---------|
| `esptool` | Flash firmware to ESP32 |
| `adafruit-ampy` | Transfer and run files on the board |
| `micropython-esp32-stubs` | Editor support for MicroPython imports |
| `ruff` | Python linter |

## Manual Steps (Reference)

If you prefer to do things manually instead of using the setup scripts:

### 1. Set Up Virtual Environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

### 2. Detect the Serial Port

```bash
ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
```

The ESP32-S3 typically shows up as `/dev/ttyACM0`.

### 3. Flash MicroPython Firmware

Download the firmware from [micropython.org](https://micropython.org/download/ESP32_GENERIC_S3/).

```bash
# Erase flash
esptool.py --port /dev/ttyACM0 erase_flash

# Write firmware
esptool.py --port /dev/ttyACM0 --baud 460800 write_flash 0 ESP32_GENERIC_S3-20250415-v1.25.0.bin
```

### 4. Run Code on the Device

```bash
# List files on the device
ampy --port /dev/ttyACM0 ls

# Run a script
ampy --port /dev/ttyACM0 run examples/micropython/blinky.py

# Upload a script to the device
ampy --port /dev/ttyACM0 put examples/micropython/blinky.py

# Make a script run on boot
ampy --port /dev/ttyACM0 put examples/micropython/blinky.py main.py
```

## Interactive REPL

To interact with MicroPython directly:

```bash
screen /dev/ttyACM0 115200
```

Or using Python's miniterm:

```bash
python -m serial.tools.miniterm /dev/ttyACM0 115200
```

- `Ctrl+C` — stop any running program
- `Ctrl+D` — soft-reset the device
- `Ctrl+A` then `K` — exit screen

## Editor Setup

After running `./scripts/pc-setup.sh`, restart your editor. MicroPython imports like `from machine import Pin` should resolve without errors.

For Zed specifically:
1. Completely quit and restart Zed (not just reload window)
2. The `.zed/settings.json` configures Zed to use the virtual environment automatically
3. `pyrightconfig.json` provides type checking configuration

If imports still show errors, verify the stubs path matches your Python version:
```bash
ls .venv/lib/python*/site-packages/machine/
```

Update the paths in `pyrightconfig.json` and `.zed/settings.json` if your Python version differs.

## Troubleshooting

### "Permission denied" on serial port

Add your user to the appropriate group (see [Prerequisites](#prerequisites)) and log out/back in.

### Device not detected

1. Check the USB cable — some cables are charge-only with no data lines
2. Try a different USB port
3. Run `dmesg | tail` after plugging in to see kernel messages
4. List available ports: `ls /dev/tty*`

### esptool can't connect

1. Hold the **BOOT** button on the board while connecting
2. Some boards require holding BOOT, pressing RESET, then releasing BOOT
3. Try a lower baud rate: `esptool.py --port /dev/ttyACM0 --baud 115200 write_flash 0 firmware.bin`

### "Import machine could not be resolved" in editor

1. Make sure you ran `./scripts/pc-setup.sh`
2. Verify stubs are installed: `source .venv/bin/activate && pip list | grep micropython`
3. Restart your editor completely
4. Run validation: `source .venv/bin/activate && python validate_setup.py`
