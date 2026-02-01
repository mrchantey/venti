import time

from machine import Pin

# ESP32-S3 onboard LED is typically on GPIO48
# Adjust this pin number if your board uses a different pin
led = Pin(48, Pin.OUT)

print("Starting blinky...")

while True:
    led.on()
    print("LED ON")
    time.sleep(0.5)

    led.off()
    print("LED OFF")
    time.sleep(0.5)
