#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# pc-setup.sh — Set up PC development environment for Venti
#
# This script prepares your local development machine with all the tools
# needed to develop MicroPython applications for ESP32 devices.
#
# What it does:
#   1. Creates a Python virtual environment (.venv/)
#   2. Installs Python dependencies (including esptool, ampy, dev tools)
#   3. Installs MicroPython type stubs for editor support
#
# Usage:
#   ./scripts/pc-setup.sh
#
# Prerequisites:
#   - Python 3.8+ installed
#   - For flashing devices: user in uucp (Arch) or dialout (Debian/Ubuntu) group
#
# Note: This script does NOT flash the ESP32. For that, use esp32-setup.sh
# ---------------------------------------------------------------------------

# Change to project root directory (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

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
# 3. Done
# --------------------------------------------------------------------------
echo ""
echo "✅ PC development environment ready!"
echo ""
echo "Next steps:"
echo "  • To set up an ESP32 device: ./scripts/esp32-setup.sh"
echo "  • To run code on a device: ./scripts/run.sh [script.py]"
echo "  • Documentation: docs/micropython/index.md"
echo ""
