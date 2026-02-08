#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# run.sh — Deploy and run MicroPython code on an ESP32 device
#
# This script uploads and executes MicroPython scripts on a connected ESP32.
# It automatically detects the device port and handles .env file uploads.
#
# What it does:
#   1. Activates the Python virtual environment
#   2. Auto-detects the ESP32 device on /dev/ttyACM* or /dev/ttyUSB*
#   3. Uploads .env file to the device (if it exists in project root)
#   4. Runs the specified MicroPython script on the device
#
# Usage:
#   ./scripts/run.sh                                    # Runs blinky.py
#   ./scripts/run.sh examples/micropython/hello-wifi.py # Runs specific script
#   ./scripts/run.sh my_script.py                       # Runs custom script
#
# Prerequisites:
#   - Run ./scripts/pc-setup.sh first to install tools
#   - ESP32 with MicroPython firmware (use ./scripts/esp32-setup.sh)
#   - Device connected via USB
#
# Notes:
#   - Script runs with no timeout by default (set AMPY_RUNTIMEOUT to override)
#   - Press Ctrl+C to stop execution
#   - .env file is automatically uploaded if present in project root
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${1:-examples/micropython/blinky.py}"

# ampy times out on long-running scripts by default — disable the run timeout
export AMPY_RUNTIMEOUT="${AMPY_RUNTIMEOUT:-0}"

# Activate virtual environment
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "❌ Virtual environment not found. Run ./scripts/pc-setup.sh first."
    exit 1
fi
source "$SCRIPT_DIR/.venv/bin/activate"

# Detect device port
detect_port() {
    for port in /dev/ttyACM* /dev/ttyUSB*; do
        if [ -e "$port" ]; then
            echo "$port"
            return 0
        fi
    done
    return 1
}

PORT=$(detect_port) || {
    echo "❌ No device found. Is your ESP32 plugged in?"
    echo "   Looked for /dev/ttyACM* and /dev/ttyUSB*"
    echo ""
    echo "   If you get permission errors, add yourself to the uucp group (Arch):"
    echo "     sudo usermod -a -G uucp \$USER"
    echo "   Then log out and back in."
    exit 1
}

echo "📡 Found device on $PORT"

# Upload .env to the board if it exists in the project root
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo "📝 Uploading .env to device..."
    ampy --port "$PORT" put "$SCRIPT_DIR/.env"
fi

echo "🚀 Running $SCRIPT on device..."
echo "   (Press Ctrl+C to stop)"
echo ""
ampy --port "$PORT" run "$SCRIPT"
