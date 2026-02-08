Consolidate the micropython setup, review these documents and move all to `docs/micropython/setup.md`.
- `setup.sh`
- `docs/micropython/first-time-setup.md`
- `docs/micropython/index.md`

So long as python is installed, setup.sh should take care of the rest.

The goal: running setup.sh should do all instructions, the final one actually running it on the device. this may include discovering and tracking the port.

`ampy run examples/micropython/blinky.py`

Also create a run.sh script that does just this run step.
