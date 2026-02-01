#!/bin/bash
set -e

echo "🌬️  Setting up Venti development environment..."
echo ""

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is not installed"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv .venv
else
    echo "✓ Virtual environment already exists"
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source .venv/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install development dependencies
echo "📥 Installing development dependencies..."
pip install -e ".[dev]"

echo ""
echo "✅ Setup complete!"
echo ""

# Run validation
if [ -f "validate_setup.py" ]; then
    echo "🔍 Running validation..."
    echo ""
    .venv/bin/python validate_setup.py
else
    echo "📝 Next steps:"
    echo ""
    echo "1. Activate the virtual environment:"
    echo "   source .venv/bin/activate"
    echo ""
    echo "2. Restart your editor (Zed) to pick up the new configuration"
    echo ""
    echo "3. Open examples/micropython/blinky.py"
    echo "   The 'import machine' error should be gone!"
    echo ""
    echo "To deactivate when you're done:"
    echo "   deactivate"
fi
