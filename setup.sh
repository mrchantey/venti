#!/bin/bash
set -e

FIRMWARE_URL="https://micropython.org/resources/firmware/ESP32_GENERIC_S3-20251209-v1.27.0.bin"
FIRMWARE_FILE=".firmware/ESP32_GENERIC_S3-20251209-v1.27.0.bin"
BLINKY_SCRIPT="examples/micropython/blinky.py"
PORT_FILE=".device-port"

echo "🌬️  Setting up Venti development environment..."
echo ""

# --------------------------------------------------------------------------
# 1. Python check
# --------------------------------------------------------------------------
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is not installed."
    echo "   On Arch: sudo pacman -S python"
    exit 1
fi

# --------------------------------------------------------------------------
# 2. Virtual environment + dependencies
# --------------------------------------------------------------------------
if [ ! -d ".venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv .venv
else
    echo "✓ Virtual environment already exists"
fi

echo "🔌 Activating virtual environment..."
source .venv/bin/activate

echo "⬆️  Upgrading pip..."
pip install --upgrade pip --quiet

echo "📥 Installing project dependencies..."
pip install -e ".[dev]" --quiet

echo "📥 Installing device tools (esptool, ampy)..."
pip install esptool adafruit-ampy --quiet

echo "✅ Python environment ready."
echo ""

# --------------------------------------------------------------------------
# 3. Detect device port
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
    echo "   • List ports: ls /dev/tty*"
    exit 1
fi

echo "✓ Found device on $PORT"
echo "$PORT" > "$PORT_FILE"

# --------------------------------------------------------------------------
# 4. Flash MicroPython firmware
# --------------------------------------------------------------------------
echo ""
echo "🔥 Preparing to flash MicroPython firmware..."

mkdir -p .firmware

if [ ! -f "$FIRMWARE_FILE" ]; then
    echo "⬇️  Downloading firmware..."
    curl -L -o "$FIRMWARE_FILE" "$FIRMWARE_URL"
else
    echo "✓ Firmware already downloaded"
fi

echo "🧹 Erasing flash..."
esptool.py --port "$PORT" erase_flash

echo "📝 Writing firmware..."
esptool.py --port "$PORT" --baud 460800 write_flash 0 "$FIRMWARE_FILE"

echo "✅ Firmware flashed. Waiting for device to reboot..."
sleep 3

# Re-detect port in case it changed after flash
PORT=$(detect_port)
if [ -z "$PORT" ]; then
    echo "⚠️  Device not found after reboot. Waiting a bit longer..."
    sleep 5
    PORT=$(detect_port)
fi

if [ -z "$PORT" ]; then
    echo "❌ Device did not come back after flashing. Unplug and replug, then run:"
    echo "   ./run.sh"
    exit 1
fi

echo "$PORT" > "$PORT_FILE"
echo "✓ Device back on $PORT"

# --------------------------------------------------------------------------
# 5. Run blinky
# --------------------------------------------------------------------------
echo ""
echo "🚀 Running blinky on device..."
echo "   (Press Ctrl+C to stop)"
echo ""

ampy --port "$PORT" run "$BLINKY_SCRIPT"
