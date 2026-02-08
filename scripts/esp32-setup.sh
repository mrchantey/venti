#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# esp32-setup.sh — Flash MicroPython firmware to ESP32 and verify setup
#
# This script sets up a new ESP32-S3 device with MicroPython firmware and
# runs a blinky test to verify everything works.
#
# What it does:
#   1. Detects the ESP32 device on /dev/ttyACM* or /dev/ttyUSB*
#   2. Downloads MicroPython firmware (if not already cached)
#   3. Erases the device's flash memory
#   4. Writes the MicroPython firmware to the device
#   5. Waits for the device to reboot
#   6. Runs blinky.py to verify the setup
#
# Usage:
#   ./scripts/esp32-setup.sh
#
# Prerequisites:
#   - Run ./scripts/pc-setup.sh first to install esptool and ampy
#   - ESP32-S3 board connected via USB
#   - User in uucp (Arch) or dialout (Debian/Ubuntu) group
#
# Troubleshooting:
#   - If esptool can't connect, try holding the BOOT button while connecting
#   - Some boards require: hold BOOT, press RESET, release BOOT
#   - Check USB cable — some are charge-only with no data lines
# ---------------------------------------------------------------------------

# Change to project root directory (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

FIRMWARE_URL="https://micropython.org/resources/firmware/ESP32_GENERIC_S3-20251209-v1.27.0.bin"
FIRMWARE_FILE=".firmware/ESP32_GENERIC_S3-20251209-v1.27.0.bin"
BLINKY_SCRIPT="examples/micropython/blinky.py"
PORT_FILE=".device-port"

echo "🌬️  ESP32 Setup — Flashing MicroPython firmware"
echo ""

# --------------------------------------------------------------------------
# 1. Check that PC setup has been run
# --------------------------------------------------------------------------
if [ ! -d ".venv" ]; then
    echo "❌ Virtual environment not found."
    echo "   Run ./scripts/pc-setup.sh first to set up your development environment."
    exit 1
fi

echo "🔌 Activating virtual environment..."
source .venv/bin/activate

# Verify esptool is available
if ! command -v esptool.py &> /dev/null; then
    echo "❌ esptool.py not found."
    echo "   Run ./scripts/pc-setup.sh to install required tools."
    exit 1
fi

# --------------------------------------------------------------------------
# 2. Detect device port
# --------------------------------------------------------------------------
detect_port() {
    local port=""
    for candidate in /dev/ttyACM* /dev/ttyUSB*; do
        if [ -e "$candidate" ]; then
            port="$candidate"
            break
        fi
    done
    echo "$port"
}

echo "🔍 Looking for ESP32 device..."
PORT=$(detect_port)

if [ -z "$PORT" ]; then
    echo "❌ No device found on /dev/ttyACM* or /dev/ttyUSB*"
    echo ""
    echo "   Troubleshooting:"
    echo "   • Is the ESP32 plugged in via USB?"
    echo "   • Do you have permission? Run:"
    echo "     sudo usermod -a -G uucp \$USER   # Arch"
    echo "     sudo usermod -a -G dialout \$USER # Debian/Ubuntu"
    echo "     Then log out and back in."
    echo "   • Check USB cable (must support data, not just charging)"
    echo "   • List all ports: ls /dev/tty*"
    echo "   • Check kernel messages: dmesg | tail"
    exit 1
fi

echo "✓ Found device on $PORT"
echo "$PORT" > "$PORT_FILE"

# --------------------------------------------------------------------------
# 3. Download firmware
# --------------------------------------------------------------------------
echo ""
echo "📥 Preparing MicroPython firmware..."

mkdir -p .firmware

if [ ! -f "$FIRMWARE_FILE" ]; then
    echo "⬇️  Downloading firmware from micropython.org..."
    curl -L -o "$FIRMWARE_FILE" "$FIRMWARE_URL"
    echo "✓ Firmware downloaded"
else
    echo "✓ Firmware already cached"
fi

# --------------------------------------------------------------------------
# 4. Flash firmware
# --------------------------------------------------------------------------
echo ""
echo "🔥 Flashing MicroPython firmware to ESP32..."
echo "   This will erase all existing data on the device."
echo ""

echo "🧹 Erasing flash memory..."
esptool.py --port "$PORT" erase_flash

echo ""
echo "📝 Writing firmware (this takes about 30 seconds)..."
esptool.py --port "$PORT" --baud 460800 write_flash 0 "$FIRMWARE_FILE"

echo ""
echo "✅ Firmware written successfully!"
echo "⏳ Waiting for device to reboot..."
sleep 3

# --------------------------------------------------------------------------
# 5. Re-detect port (it may change after flashing)
# --------------------------------------------------------------------------
PORT=$(detect_port)
if [ -z "$PORT" ]; then
    echo "⚠️  Device not found after reboot. Waiting a bit longer..."
    sleep 5
    PORT=$(detect_port)
fi

if [ -z "$PORT" ]; then
    echo ""
    echo "⚠️  Device did not reappear after flashing."
    echo "   This is sometimes normal. Try unplugging and replugging the device."
    echo "   Then run: ./scripts/run.sh"
    echo ""
    echo "   If that works, your ESP32 is ready to use!"
    exit 1
fi

echo "✓ Device reconnected on $PORT"
echo "$PORT" > "$PORT_FILE"

# --------------------------------------------------------------------------
# 6. Run blinky to verify setup
# --------------------------------------------------------------------------
echo ""
echo "🚀 Running blinky.py to verify setup..."
echo "   You should see the onboard LED blinking."
echo "   (Press Ctrl+C to stop)"
echo ""

sleep 1  # Give the device a moment to fully boot

if [ ! -f "$BLINKY_SCRIPT" ]; then
    echo "⚠️  Warning: $BLINKY_SCRIPT not found"
    echo "   Firmware is installed, but can't run test."
    echo ""
    echo "✅ ESP32 is ready! Run code with: ./scripts/run.sh <script.py>"
    exit 0
fi

ampy --port "$PORT" run "$BLINKY_SCRIPT" || {
    echo ""
    echo "⚠️  Blinky test failed, but firmware may still be installed correctly."
    echo "   Try running: ./scripts/run.sh $BLINKY_SCRIPT"
    echo ""
    echo "   If you see errors about 'machine' module, the firmware flash may have failed."
    echo "   Try running this script again."
    exit 1
}

echo ""
echo "======================================"
echo "  ✅  ESP32 Setup Complete!"
echo "======================================"
echo ""
echo "Your ESP32 is running MicroPython and ready for development."
echo ""
echo "Next steps:"
echo "  • Run code: ./scripts/run.sh examples/micropython/blinky.py"
echo "  • See all examples: ls examples/micropython/"
echo "  • Read docs: docs/micropython/index.md"
echo ""
