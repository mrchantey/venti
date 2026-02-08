#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${1:-examples/micropython/blinky.py}"

# Activate virtual environment
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "❌ Virtual environment not found. Run ./setup.sh first."
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
echo "🚀 Running $SCRIPT on device..."
echo "   (Press Ctrl+C to stop)"
echo ""
ampy --port "$PORT" run "$SCRIPT"
