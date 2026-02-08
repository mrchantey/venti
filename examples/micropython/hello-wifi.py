# Connect to WiFi and fetch a webpage
#
# Upload .env to the board first, then run:
# ```sh
# ampy --port /dev/ttyACM0 put .env
# ampy --port /dev/ttyACM0 run --no-output examples/micropython/hello-wifi.py
# ```
import time

import network
import urequests


def load_env(path=".env"):
    """Parse a .env file from the board's filesystem into a dict."""
    env = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                key, value = line.split("=", 1)
                env[key.strip()] = value.strip()
    except OSError:
        print(f"ERROR: could not open {path}")
        print("Upload it first:  ampy --port /dev/ttyACM0 put .env")
        raise SystemExit
    return env


def connect_wifi(ssid, password, timeout_s=15):
    """Connect to a WiFi network and return the WLAN interface."""
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)

    if wlan.isconnected():
        print(f"Already connected to {ssid}")
        print(f"  IP: {wlan.ifconfig()[0]}")
        return wlan

    print(f"Connecting to '{ssid}'...", end="")
    wlan.connect(ssid, password)

    start = time.time()
    while not wlan.isconnected():
        if time.time() - start > timeout_s:
            print(" FAILED")
            print(f"Could not connect to '{ssid}' within {timeout_s}s")
            raise SystemExit
        print(".", end="")
        time.sleep(1)

    print(" OK")
    print(f"  IP: {wlan.ifconfig()[0]}")
    return wlan


def main():
    env = load_env()

    ssid = env.get("WIFI_SSID")
    password = env.get("WIFI_PASSWORD")

    if not ssid or not password:
        print("ERROR: .env must contain WIFI_SSID and WIFI_PASSWORD")
        raise SystemExit

    connect_wifi(ssid, password)

    url = "http://example.com"
    print(f"\nFetching {url} ...")
    response = urequests.get(url)
    print(f"Status: {response.status_code}\n")
    print(response.text)
    response.close()


main()
