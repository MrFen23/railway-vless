#!/bin/sh
# Renders all configs from env vars, then supervises:
#   1. geo-update loop (background)
#   2. xray-supervisor (background) — auto-restarts Xray, reloads geo on USR1
#   3. nginx (foreground, becomes PID 1 via exec)
set -e

: "${PORT:=8080}"

# --- Resolve UUIDS: prefer UUIDS, fall back to legacy UUID (bug fix #1) ---
if [ -n "${UUIDS:-}" ]; then
    :
elif [ -n "${UUID:-}" ]; then
    echo "[entrypoint] NOTE: UUIDS not set — using legacy UUID."
    UUIDS="${UUID}"
else
    echo "[entrypoint] ERROR: UUIDS (or legacy UUID) env var is required." >&2
    exit 1
fi

# --- Secrets with random defaults (so the box works even if unset) ---
gen_secret() { tr -dc 'a-z0-9' < /dev/urandom | head -c 12; }
WS_PATH="${WS_PATH:-/$(gen_secret)}"
QR_PATH="${QR_PATH:-/$(gen_secret)}"

# URL-encode the WS path for the share link.
WS_PATH_ENC=$(printf '%s' "${WS_PATH}" | sed 's|/|%2F|g')

# --- Build Xray clients array from UUIDS ---
CLIENTS=""
FIRST=1
PRIMARY_UUID=""
IFS=','
for uuid in ${UUIDS}; do
    uuid=$(echo "${uuid}" | tr -d ' ')
    [ -z "${uuid}" ] && continue
    if [ "${FIRST}" -eq 1 ]; then
        CLIENTS="{ \"id\": \"${uuid}\" }"
        FIRST=0
        PRIMARY_UUID="${uuid}"
    else
        CLIENTS="${CLIENTS}, { \"id\": \"${uuid}\" }"
    fi
done
unset IFS

if [ -z "${CLIENTS}" ]; then
    echo "[entrypoint] ERROR: no valid UUID found in UUIDS='${UUIDS}'" >&2
    exit 1
fi

# Show a masked hint instead of leaking full secrets to logs.
mask() { echo "$1" | sed 's/\(....\).*\(....\)/\1...\2/'; }
echo "[entrypoint] PORT      = ${PORT}"
echo "[entrypoint] UUIDS     = $(mask "${PRIMARY_UUID}") (+$(($(echo "${UUIDS}" | tr ',' '\n' | grep -c .) - 1)) more)"
echo "[entrypoint] WS_PATH   = ${WS_PATH}"
echo "[entrypoint] QR_PATH   = ${QR_PATH}"

# --- Render nginx.conf ---
sed -e "s|{{PORT}}|${PORT}|g" \
    -e "s|{{WS_PATH}}|${WS_PATH}|g" \
    -e "s|{{QR_PATH}}|${QR_PATH}|g" \
    /app/nginx.conf > /app/nginx-runtime.conf

# --- Render xray config.json ---
sed -e "s|{{CLIENTS}}|${CLIENTS}|g" \
    -e "s|{{WS_PATH}}|${WS_PATH}|g" \
    /app/config-template.json > /app/config.json

# --- Render QR page ---
DOMAIN="${DOMAIN:-${RAILWAY_PUBLIC_DOMAIN:-}}"
if [ -z "${DOMAIN}" ]; then
    echo "[entrypoint] WARNING: DOMAIN not set — QR page will show a placeholder."
    echo "[entrypoint]          Set DOMAIN=<your>.up.railway.app for the share link."
fi
sed -e "s|{{DOMAIN}}|${DOMAIN}|g" \
    -e "s|{{UUID}}|${PRIMARY_UUID}|g" \
    -e "s|{{WS_PATH_ENC}}|${WS_PATH_ENC}|g" \
    /app/www/qr.html > /app/www/qr-runtime.html
sed -i "s|/qr.html|/qr-runtime.html|g" /app/nginx-runtime.conf

# --- Launch background processes ---
echo "[entrypoint] starting geo-update loop..."
sh /app/geo-update.sh &

echo "[entrypoint] starting xray supervisor..."
sh /app/xray-supervisor.sh &
SUPER_PID=$!

# --- Graceful shutdown: stop background processes, then nginx exits ---
cleanup() {
    echo "[entrypoint] shutdown — stopping background processes..."
    touch /tmp/xray-stop
    kill "${SUPER_PID}" 2>/dev/null
    pkill -f "geo-update.sh" 2>/dev/null
    nginx -s stop 2>/dev/null
}
trap cleanup TERM INT

echo "[entrypoint] starting nginx (PID 1)..."
# exec replaces the shell with nginx — it becomes PID 1, receives SIGTERM from
# Railway directly, and the container shuts down cleanly on redeploy.
exec nginx -c /app/nginx-runtime.conf -g 'daemon off;'
