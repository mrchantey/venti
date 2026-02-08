#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# home-assistant.sh — Start Home Assistant + Mosquitto MQTT broker via Docker
#
# Usage:
#   ./home-assistant.sh          # Start everything
#   ./home-assistant.sh stop     # Stop and remove containers
#   ./home-assistant.sh status   # Show container status
#   ./home-assistant.sh test     # Publish/subscribe test message
# ---------------------------------------------------------------------------

HA_CONTAINER="homeassistant"
MQTT_CONTAINER="mosquitto"
HA_CONFIG_DIR="/opt/homeassistant"
MQTT_CONFIG_DIR="/opt/mosquitto"
TZ="Australia/Sydney"
MQTT_PORT=1883
HA_PORT=8123

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No colour

info()  { echo -e "${CYAN}$*${NC}"; }
ok()    { echo -e "${GREEN}✓ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $*${NC}"; }
err()   { echo -e "${RED}✗ $*${NC}"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

get_host_ip() {
    ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[\d.]+' || \
    ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1
}

wait_for_port() {
    local port=$1 label=$2 max=$3
    info "Waiting for $label on port $port..."
    for i in $(seq 1 "$max"); do
        if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
           nc -z localhost "$port" 2>/dev/null; then
            ok "$label is listening on port $port"
            return 0
        fi
        printf "."
        sleep 1
    done
    echo ""
    err "$label did not start within ${max}s"
    return 1
}

wait_for_ha() {
    info "Waiting for Home Assistant to be ready (this can take a minute on first boot)..."
    for i in $(seq 1 90); do
        code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${HA_PORT}/" 2>/dev/null || true)
        if [ "$code" = "200" ] || [ "$code" = "401" ]; then
            ok "Home Assistant is ready"
            return 0
        fi
        printf "."
        sleep 2
    done
    echo ""
    warn "Home Assistant may still be starting — check http://localhost:${HA_PORT}"
    return 0
}

# ---------------------------------------------------------------------------
# stop — tear down containers
# ---------------------------------------------------------------------------
do_stop() {
    info "Stopping containers..."
    for c in "$HA_CONTAINER" "$MQTT_CONTAINER"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
            docker stop "$c" >/dev/null 2>&1 || true
            docker rm "$c" >/dev/null 2>&1 || true
            ok "Removed $c"
        else
            echo "  $c not running"
        fi
    done
}

# ---------------------------------------------------------------------------
# status
# ---------------------------------------------------------------------------
do_status() {
    echo ""
    info "=== Container Status ==="
    for c in "$MQTT_CONTAINER" "$HA_CONTAINER"; do
        status=$(docker ps -a --filter "name=^${c}$" --format '{{.Status}}' 2>/dev/null)
        if [ -z "$status" ]; then
            echo "  $c: not created"
        else
            echo "  $c: $status"
        fi
    done
    echo ""
}

# ---------------------------------------------------------------------------
# test — quick MQTT publish/subscribe sanity check
# ---------------------------------------------------------------------------
do_test() {
    info "Testing MQTT broker..."

    # Subscribe in background, wait for one message
    docker exec "$MQTT_CONTAINER" mosquitto_sub \
        -h localhost -p "$MQTT_PORT" \
        -t "venti/test" -C 1 -W 5 &
    SUB_PID=$!
    sleep 1

    # Publish
    docker exec "$MQTT_CONTAINER" mosquitto_pub \
        -h localhost -p "$MQTT_PORT" \
        -t "venti/test" -m "hello from home-assistant.sh"

    wait $SUB_PID 2>/dev/null && ok "MQTT pub/sub is working" || err "MQTT test failed"
}

# ---------------------------------------------------------------------------
# start — main setup
# ---------------------------------------------------------------------------
do_start() {
    HOST_IP=$(get_host_ip)
    echo ""
    echo "======================================"
    echo "  🌬️  Venti — Home Assistant Setup"
    echo "======================================"
    echo ""

    # ------------------------------------------------------------------
    # 1. Stop existing containers
    # ------------------------------------------------------------------
    do_stop
    echo ""

    # ------------------------------------------------------------------
    # 2. Set up Mosquitto config
    # ------------------------------------------------------------------
    info "Setting up Mosquitto configuration..."

    sudo mkdir -p "${MQTT_CONFIG_DIR}/config" \
                  "${MQTT_CONFIG_DIR}/data" \
                  "${MQTT_CONFIG_DIR}/log"

    sudo tee "${MQTT_CONFIG_DIR}/config/mosquitto.conf" > /dev/null <<'MQTTCONF'
# Mosquitto config for Venti development
listener 1883
allow_anonymous true

persistence true
persistence_location /mosquitto/data/

log_dest stdout
log_type error
log_type warning
log_type notice
log_type information

# Allow clients to set retain flag (needed for HA MQTT discovery)
retain_available true
MQTTCONF

    ok "Mosquitto config written to ${MQTT_CONFIG_DIR}/config/mosquitto.conf"

    # ------------------------------------------------------------------
    # 3. Start Mosquitto
    # ------------------------------------------------------------------
    info "Starting Mosquitto MQTT broker..."

    docker run -d \
        --name "$MQTT_CONTAINER" \
        --restart=unless-stopped \
        --network=host \
        -v "${MQTT_CONFIG_DIR}/config:/mosquitto/config:ro" \
        -v "${MQTT_CONFIG_DIR}/data:/mosquitto/data" \
        -v "${MQTT_CONFIG_DIR}/log:/mosquitto/log" \
        eclipse-mosquitto:2 >/dev/null

    wait_for_port "$MQTT_PORT" "Mosquitto" 15
    echo ""

    # ------------------------------------------------------------------
    # 4. Start Home Assistant
    # ------------------------------------------------------------------
    info "Starting Home Assistant..."

    sudo mkdir -p "$HA_CONFIG_DIR"

    docker run -d \
        --name "$HA_CONTAINER" \
        --restart=unless-stopped \
        --network=host \
        -v "${HA_CONFIG_DIR}:/config" \
        -e TZ="$TZ" \
        ghcr.io/home-assistant/home-assistant:stable >/dev/null

    wait_for_port "$HA_PORT" "Home Assistant" 30
    wait_for_ha
    echo ""

    # ------------------------------------------------------------------
    # 5. Quick MQTT sanity check
    # ------------------------------------------------------------------
    info "Running MQTT sanity check..."
    sleep 2
    if docker exec "$MQTT_CONTAINER" mosquitto_pub \
        -h localhost -p "$MQTT_PORT" \
        -t "venti/healthcheck" -m "ok" 2>/dev/null; then
        ok "MQTT broker accepts messages"
    else
        warn "Could not publish test message — broker may still be starting"
    fi
    echo ""

    # ------------------------------------------------------------------
    # 6. Print summary and next steps
    # ------------------------------------------------------------------
    echo "======================================"
    echo "  ✅  Everything is running"
    echo "======================================"
    echo ""
    echo "  Home Assistant:  http://localhost:${HA_PORT}"
    echo "                   http://${HOST_IP}:${HA_PORT}"
    echo "  MQTT Broker:     ${HOST_IP}:${MQTT_PORT}"
    echo ""
    echo "--------------------------------------"
    echo "  Next steps"
    echo "--------------------------------------"
    echo ""
    echo "  1. Open Home Assistant in your browser and create an account"
    echo "     (skip if you've already done this)"
    echo ""
    echo "  2. Add the MQTT integration:"
    echo "     Settings → Devices & Services → Add Integration → search \"MQTT\""
    echo ""
    echo "     Broker:   localhost"
    echo "     Port:     ${MQTT_PORT}"
    echo "     Username: (leave blank)"
    echo "     Password: (leave blank)"
    echo ""
    echo "  3. Update your .env file on the ESP32:"
    echo ""
    echo "     MQTT_BROKER=${HOST_IP}"
    echo "     MQTT_PORT=${MQTT_PORT}"
    echo "     MQTT_USER="
    echo "     MQTT_PASSWORD="
    echo ""
    echo "  4. Upload and run the example on the device:"
    echo ""
    echo "     ./run.sh examples/micropython/hello-home-assistant.py"
    echo ""
    echo "  5. The potentiometer and fan will auto-appear in Home Assistant"
    echo "     under Settings → Devices & Services → MQTT → venti-esp32"
    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
case "${1:-start}" in
    start)  do_start ;;
    stop)   do_stop ;;
    status) do_status ;;
    test)   do_test ;;
    *)
        echo "Usage: $0 {start|stop|status|test}"
        exit 1
        ;;
esac
