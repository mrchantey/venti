# Venti Scripts

All shell scripts for the Venti project are located in this directory.

## Available Scripts

| Script | Purpose | Frequency |
|--------|---------|-----------|
| `pc-setup.sh` | Set up PC development environment | Once (initial setup) |
| `esp32-setup.sh` | Flash MicroPython firmware to ESP32 | Once per device |
| `run.sh` | Run MicroPython code on device | Every development iteration |
| `home-assistant.sh` | Start/manage Home Assistant + MQTT | As needed for HA work |

## Quick Start

```bash
# 1. First time setup
./scripts/pc-setup.sh

# 2. Flash your ESP32
./scripts/esp32-setup.sh

# 3. Run code
./scripts/run.sh examples/micropython/blinky.py
```

## Migration Guide

If you've used older versions of this project, note these changes:

| Old Command | New Command |
|-------------|-------------|
| `./setup.sh` | `./scripts/pc-setup.sh` |
| `./run.sh` | `./scripts/run.sh` |
| `./home-assistant.sh` | `./scripts/home-assistant.sh` |
| N/A | `./scripts/esp32-setup.sh` (new!) |

### What Changed?

- **All scripts moved to `scripts/` directory** for better organization
- **`setup.sh` split into two scripts**:
  - `pc-setup.sh` — PC environment setup only
  - `esp32-setup.sh` — Device flashing only
- **Better documentation** — each script has detailed headers
- **All scripts work from project root** — they automatically `cd` to the right place

## Script Details

### pc-setup.sh

**Purpose**: One-time setup of your development machine.

**What it does**:
- Creates Python virtual environment (`.venv/`)
- Installs Python dependencies
- Installs esptool and ampy
- Installs MicroPython type stubs for editor support

**When to run**: Once before starting development, or when dependencies change.

```bash
./scripts/pc-setup.sh
```

### esp32-setup.sh

**Purpose**: Flash MicroPython firmware to an ESP32 device.

**What it does**:
- Detects ESP32 on USB port
- Downloads MicroPython firmware (if needed)
- Erases device flash
- Writes firmware
- Runs blinky test to verify

**When to run**: Once per new device, or when updating firmware.

```bash
./scripts/esp32-setup.sh
```

**Troubleshooting**:
- If esptool can't connect, hold the BOOT button while running the script
- Check USB cable (must be data-capable, not charge-only)
- Verify you're in the `uucp` (Arch) or `dialout` (Debian/Ubuntu) group

### run.sh

**Purpose**: Deploy and run MicroPython scripts on your ESP32.

**What it does**:
- Auto-detects device port
- Uploads `.env` file (if it exists)
- Runs your MicroPython code on the device

**When to run**: Every time you want to test code.

```bash
# Run default (blinky)
./scripts/run.sh

# Run specific script
./scripts/run.sh examples/micropython/hello-wifi.py

# Run custom script
./scripts/run.sh my_script.py
```

### home-assistant.sh

**Purpose**: Manage Home Assistant and Mosquitto MQTT broker via Docker.

**What it does**:
- Starts/stops Home Assistant and Mosquitto containers
- Configures MQTT broker
- Opens firewall ports (if ufw is active)
- Provides status and testing commands

**When to run**: When working on Home Assistant integration.

```bash
./scripts/home-assistant.sh          # Start services
./scripts/home-assistant.sh stop     # Stop services
./scripts/home-assistant.sh status   # Check status
./scripts/home-assistant.sh test     # Test MQTT
```

## Documentation

For detailed guides, see:
- **[docs/micropython/index.md](../docs/micropython/index.md)** - Quickstart and overview
- **[docs/micropython/setup.md](../docs/micropython/setup.md)** - Detailed setup reference
- **[docs/micropython/home-assistant.md](../docs/micropython/home-assistant.md)** - Home Assistant integration

## Prerequisites

- **Python 3.8+** installed
- **ESP32-S3 board** connected via USB
- **Docker** (optional, only for Home Assistant work)
- **User permissions**: Add yourself to `uucp` (Arch) or `dialout` (Debian/Ubuntu) group:

```bash
# Arch Linux
sudo usermod -a -G uucp $USER

# Debian/Ubuntu
sudo usermod -a -G dialout $USER

# Log out and back in
```

## Notes

- All scripts automatically change to the project root directory
- Scripts can be run from anywhere in the project
- Scripts are designed to be idempotent (safe to run multiple times)
- Each script has comprehensive error messages and troubleshooting tips