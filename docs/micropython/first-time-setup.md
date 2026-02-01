# Development Setup

This guide explains how to set up your development environment for the Venti project.

## Quick Start

Run the setup script to create a virtual environment and install all dependencies:

```bash
chmod +x setup.sh
./setup.sh
```

**That's it!** The script will:
- Create a Python virtual environment (`.venv/`)
- Install MicroPython stubs so your editor understands ESP32 code
- Install development tools (like `ruff` for linting)

Your environment is ready. For more details, see [DEVELOPMENT.md](./DEVELOPMENT.md).

## What is a Virtual Environment (venv)?

A **virtual environment** is an isolated Python environment for your project. Think of it as a sandbox where you can install Python packages without affecting your system-wide Python installation or other projects.

### Why use venv?

- **Isolation**: Each project has its own dependencies
- **Reproducibility**: Easy to recreate the exact same environment
- **No conflicts**: Different projects can use different versions of the same package
- **No sudo**: Install packages without root/administrator privileges

### Manual Setup (if you don't want to use the setup script)

```bash
# Create the virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate

# Install dependencies
pip install -e ".[dev]"
```

## Daily Workflow

### Activating the Virtual Environment

Every time you open a new terminal to work on this project:

```bash
source .venv/bin/activate
```

You'll see `(.venv)` appear in your prompt, indicating the venv is active.

### Deactivating

When you're done working:

```bash
deactivate
```

## MicroPython Development

The `examples/micropython/` directory contains code meant to run on microcontrollers (like ESP32), not on your development machine.

### Why does my editor complain about `import machine`?

The `machine` module is part of MicroPython, not regular Python. We've installed `micropython-esp32-stubs` which provides type hints so your editor understands these imports.

### Editor Configuration

The project includes configuration for **Pyright** and **BasedPyright** (the type checker Zed uses). This is in `pyproject.toml`.

After running `./setup.sh`, restart Zed. It should now recognize MicroPython imports like `from machine import Pin`.

The `.zed/settings.json` file configures Zed to use the virtual environment automatically, and `pyrightconfig.json` provides additional configuration that basedpyright respects.

If you're still seeing errors in Zed:

1. Make sure you've run `./setup.sh`
2. **Completely quit and restart Zed** (not just reload window)
3. Check that Zed is using the `.venv` Python interpreter
4. Run the validation script: `source .venv/bin/activate && python validate_setup.py`
5. Check that the path to `.venv/lib/python3.13/site-packages` is correct for your Python version

If Zed still shows errors:
1. Open Zed's command palette (Cmd/Ctrl+Shift+P)
2. Run "zed: open log"
3. Look for Python LSP errors
4. Update paths if needed in:
   - `pyrightconfig.json` (line 5: extraPaths)
   - `.zed/settings.json` (python.analysis.extraPaths)

## pip vs pipx

- **pip**: Installs packages into the current Python environment (use with venv!)
- **pipx**: Installs Python CLI tools globally in isolated environments (for tools like `black`, `ruff`, etc.)

For **this project**, use **pip** inside the virtual environment. Use pipx for global CLI tools you want available everywhere.

## Project Structure

```
venti/
├── .venv/                  # Virtual environment (gitignored)
├── examples/
│   └── micropython/        # Code that runs on ESP32/microcontrollers
├── docs/                   # Documentation
├── pyproject.toml          # Python project configuration
├── setup.sh               # Setup script
├── .gitignore             # Git ignore rules
└── README.md              # Project overview
```

## Troubleshooting

### "Import machine could not be resolved"

1. Make sure you ran `./setup.sh`
2. Activate the venv: `source .venv/bin/activate`
3. Verify stubs are installed: `pip list | grep micropython`
4. Run validation: `python validate_setup.py`
5. **Completely quit and restart Zed** (not just reload)
6. If still broken, check your Python version and update paths in:
   - `pyrightconfig.json` (line 5: extraPaths)
   - `.zed/settings.json` (python.analysis.extraPaths)

### "python3: command not found"

Install Python 3 on Arch:
```bash
sudo pacman -S python
```

### Virtual environment not activating

Make sure you're in the project root directory (`/home/pete/me/venti`) when running `source .venv/bin/activate`.
