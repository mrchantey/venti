# ESP32 Micropython

Installation instructions for ESP32-S3

## 1. Install MicroPython Firmware

1. get [esptool](https://docs.espressif.com/projects/esptool/en/latest/esp32s3/)
	`pip install esptool`
2. erase flash
	`esptool.py --port /dev/ttyACM0 erase-flash`

2. install [micropython firmware](https://micropython.org/download/ESP32_GENERIC_S3/)
	`esptool.py --port /dev/ttyACM0 --baud 460800 write_flash 0 /home/pete/Downloads/ESP32_GENERIC_S3-20251209-v1.27.0.bin`

## 2. Install File Transfer Tool

1. Install [ampy](https://github.com/scientifichackers/ampy) (Adafruit MicroPython tool) for file transfers:
	
	On Arch Linux (or systems with externally-managed Python):
	`pipx install adafruit-ampy`
	
	On other systems:
	`pip install adafruit-ampy`

## 3. Upload and Run blinky.py

1. List files on the device to verify connection:
	`ampy --port /dev/ttyACM0 ls`

2. Upload the blinky script to the device:
	`ampy --port /dev/ttyACM0 put examples/micropython/blinky.py`

3. Run the blinky script:
	`ampy --port /dev/ttyACM0 run examples/micropython/blinky.py`
	
	The LED should start blinking! You'll see output like:
	```
	Starting blinky...
	LED ON
	LED OFF
	LED ON
	LED OFF
	```
	
	Press `Ctrl+C` to stop the script.

4. To make blinky run automatically on boot, upload it as `main.py`:
	`ampy --port /dev/ttyACM0 put examples/micropython/blinky.py main.py`
	
	Then reset the device to see it run on startup.

## 4. Interactive REPL (Optional)

To interact with MicroPython directly, connect using a serial terminal:

`screen /dev/ttyACM0 115200`

Or using Python's miniterm:
`python -m serial.tools.miniterm /dev/ttyACM0 115200`

Press `Ctrl+C` to stop any running program and `Ctrl+D` to soft-reset the device.

## Troubleshooting

- If you get permission errors accessing `/dev/ttyACM0`, add your user to the dialout group (or `uucp` on Arch):
	`sudo usermod -a -G dialout $USER`  (or `uucp` on Arch)
	Then log out and log back in.

- If the port is different, list available ports:
	`ls /dev/tty*`
	Look for `/dev/ttyUSB0`, `/dev/ttyACM0`, or similar.

- To see files on the device:
	`ampy --port /dev/ttyACM0 ls`

- To remove a file from the device:
	`ampy --port /dev/ttyACM0 rm main.py`
