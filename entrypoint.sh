#!/bin/sh
# Renders all configs from env vars, then supervises:
#   1. geo-update loop (background)
#   2. Xray (background)
#   3. nginx (foreground)
set -e

: "${UUIDS:?UUIDS env var is required (comma-separated UUIDs)}"
: "${PORT:=8080}"

# Backwards-compat: accept legacy UUID too.
if [ -z "${UUIDS}" ] && [ -n "${UUID}" ]; then
    UUIDS="${UUID}"
fi

# --- Secrets with random defaults (so the box works even if unset) ---
gen_secret() { tr -dc 'a-z0-9' < /dev/urandom | head -c 12; }
WS_PATH="${WS_PATH:-/$(gen_secret)}"
QR_PATH="${QR_PATH:-/$(gen_secret)}"

# URL-encode the WS path for the share link (only "/" needs encoding).
WS_PATH_ENC=$(printf '%s' "${WS_PATH}" | sed 's|/|%2F|g')

# --- Build Xray clients array from UUIDS ---
CLIENTS=""
FIRST=1
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

echo "[entrypoint] PORT      = ${PORT}"
echo "[entrypoint] UUIDS     = ${UUIDS}"
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

# --- Render QR page (used by entrypoint-injected values) ---
# DOMAIN is the Railway public hostname; auto-detect via $RAILWAY_PUBLIC_DOMAIN
DOMAIN="${DOMAIN:-${RAILWAY_PUBLIC_DOMAIN:-}}"
if [ -z "${DOMAIN}" ]; then
    echo "[entrypoint] WARNING: DOMAIN not set — QR page will show a placeholder."
    echo "[entrypoint]          Set DOMAIN=<your>.up.railway.app for the share link."
fi
sed -e "s|{{DOMAIN}}|${DOMAIN}|g" \
    -e "s|{{UUID}}|${PRIMARY_UUID}|g" \
    -e "s|{{WS_PATH_ENC}}|${WS_PATH_ENC}|g" \
    /app/www/qr.html > /app/www/qr-runtime.html

# Point nginx at the rendered QR page.
sed -i "s|/qr.html|/qr-runtime.html|g" /app/nginx-runtime.conf

# --- Launch processes ---
echo "[entrypoint] starting geo-update loop..."
sh /app/geo-update.sh &

echo "[entrypoint] starting Xray..."
/app/xray run -config /app/config.json &

echo "[entrypoint] starting nginx..."
# Foreground: nginx keeps the container alive. Awaits SIGTERM from Railway.
nginx -c /app/nginx-runtime.conf -g 'daemon off;'
