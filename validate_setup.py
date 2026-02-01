#!/usr/bin/env python3
"""
Validation script to verify the development environment is set up correctly.

Run this after setup.sh to confirm MicroPython stubs are installed and working.
"""

import sys
from pathlib import Path


def main():
    print("🔍 Validating Venti development environment...\n")

    # Check if we're in a virtual environment
    in_venv = hasattr(sys, "real_prefix") or (
        hasattr(sys, "base_prefix") and sys.base_prefix != sys.prefix
    )

    if in_venv:
        print("✅ Virtual environment is active")
        print(f"   Python: {sys.executable}")
        print(f"   Version: {sys.version.split()[0]}")
    else:
        print("⚠️  WARNING: Not in a virtual environment!")
        print("   Run: source .venv/bin/activate")
        return 1

    # Check for MicroPython stubs
    try:
        import micropython_esp32_stubs

        print("❌ micropython_esp32_stubs should not be importable (stubs only)")
    except ImportError:
        print("✅ MicroPython ESP32 stubs installed (stubs are type-only)")

    # Check if stub files exist
    site_packages = (
        Path(sys.prefix)
        / "lib"
        / f"python{sys.version_info.major}.{sys.version_info.minor}"
        / "site-packages"
    )
    machine_stub = site_packages / "machine.pyi"

    if machine_stub.exists():
        print(f"✅ machine.pyi stub file found")
        print(f"   Location: {machine_stub}")
    else:
        print(f"❌ machine.pyi stub file NOT found")
        print(f"   Expected at: {machine_stub}")
        return 1

    # Check for ruff
    try:
        import ruff

        print("✅ Ruff linter installed")
    except ImportError:
        print("⚠️  Ruff not found (optional)")

    # Check project files
    project_root = Path(__file__).parent
    required_files = [
        "pyproject.toml",
        "pyrightconfig.json",
        ".zed/settings.json",
    ]

    print("\n📁 Checking project files:")
    all_found = True
    for file_path in required_files:
        full_path = project_root / file_path
        if full_path.exists():
            print(f"   ✅ {file_path}")
        else:
            print(f"   ❌ {file_path} missing")
            all_found = False

    if not all_found:
        return 1

    print("\n🎉 Environment validation complete!")
    print("\n📝 Next steps:")
    print("   1. Restart your editor (Zed) to pick up the new configuration")
    print("   2. Open examples/micropython/blinky.py")
    print("   3. The 'import machine' error should be gone!")
    print("\n   If you still see errors, check DEVELOPMENT.md for troubleshooting.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
