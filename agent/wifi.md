there is an ESP32 connected, try running with timeout:
`ampy --port /dev/ttyACM0 run examples/micropython/pot-fan.py`
to see it in action.


create a new example: examples/micropython/hello-wifi.py

1. it loads the ssid and password from `.env`
2. connects to wifi
3. fetches example.com and prints the page

use timeout when running to avoid getting stuck



When thats done create a new example: `hello-home-assistant`

See `pot-fan`, it should expose both the pot value and the fan to home assistant.
Also add a docs/micropython/home-assistant.md to add instructions for setting up home assistant and running the example, to see its pot and control its fan etc. 

dont actually install home assistant yet, just the guide at this stage.
