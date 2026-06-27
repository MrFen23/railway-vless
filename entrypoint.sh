#!/bin/sh
# Generates config.json from template using Railway env vars, then starts Xray.
set -e

: "${UUID:?UUID env var is required}"
: "${PORT:=${PORT:-8080}}"

echo "[entrypoint] UUID  = ${UUID}"
echo "[entrypoint] PORT  = ${PORT}"

# Render template by replacing {{PORT}} and {{UUID}} placeholders.
sed -e "s|{{PORT}}|${PORT}|g" \
    -e "s|{{UUID}}|${UUID}|g" \
    /app/config-template.json > /app/config.json

echo "[entrypoint] Starting Xray..."
exec /app/xray run -config /app/config.json
