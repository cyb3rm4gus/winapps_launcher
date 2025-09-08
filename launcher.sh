#!/usr/bin/env bash
set -euo pipefail

# ===== CONFIG =====
COMPOSE_FILE="/home/<your_linux_user>/winapps/docker-compose.yaml" # insert your username into the home folder path
PROJECT_NAME="winapps"
SERVICE="windows"
WAIT_SECS=10

# FreeRDP binary + hard-coded creds (adjust!)
FREERDP_BIN="$(command -v xfreerdp3 || command -v xfreerdp || true)"
FREERDP_ARGS=(/u:"user" /p:"<WINDOWS_PASSWORD>" /v:127.0.0.1 /cert:tofu /dynamic-resolution) # insert your windows password that you set up on first launch of docker compose
# ==================

command -v docker >/dev/null || { echo "docker not found"; exit 127; }
docker compose version >/dev/null 2>&1 || { echo "'docker compose' v2 not available"; exit 127; }
[ -x "$FREERDP_BIN" ] || { echo "FreeRDP not found (xfreerdp3/xfreerdp)"; exit 127; }
command -v systemd-run >/dev/null || { echo "systemd-run not found"; exit 127; }

DC() { docker compose --project-name "$PROJECT_NAME" -f "$COMPOSE_FILE" "$@"; }
DC config --services | grep -Fxq "$SERVICE" || { echo "Service '$SERVICE' not found in $COMPOSE_FILE"; exit 2; }

if [ -n "$(DC ps -q "$SERVICE")" ]; then
  echo "[*] $SERVICE is running → stopping..."
  DC stop "$SERVICE" >/dev/null
  echo "[✓] Stopped."
  exit 0
fi

echo "[*] Starting $SERVICE..."
DC up -d "$SERVICE" >/dev/null
echo "✔ Started: $SERVICE"

echo "[*] Waiting ${WAIT_SECS}s..."
sleep "$WAIT_SECS"

echo "[*] Launching FreeRDP..."

# Preserve GUI environment for the detached process
DISPLAY=${DISPLAY:-:0}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$UID}
XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}
DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$UID/bus}

# Spawn as a transient user unit so it keeps running when the terminal closes
UNIT="freerdp-$(date +%s)"

systemd-run --user --quiet --collect --unit="$UNIT" \
  --setenv=DISPLAY="$DISPLAY" \
  --setenv=XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  --setenv=XAUTHORITY="$XAUTHORITY" \
  --setenv=DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  "$FREERDP_BIN" "${FREERDP_ARGS[@]}"

exit 0

