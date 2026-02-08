import time

from machine import ADC, PWM, Pin

# GPIO6 potentiometer input
pot = ADC(Pin(6))

# GPIO7 PWM pin for fan
pwm_pin = PWM(Pin(7))

# Set frequency (default is usually 1000 Hz)
pwm_pin.freq(1000)


while True:
    # Read potentiometer value (0-1023 range)
    pot_value = pot.read_u16()
    # Normalize to 0-1023 range (read_u16 returns 0-65535)
    normalized_value = pot_value // 64
    # Set fan speed to potentiometer level
    pwm_pin.duty(normalized_value)
    time.sleep(0.1)
    print(f"Fan speed set to {normalized_value} (pot level)")
