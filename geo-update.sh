#!/bin/sh
# Periodically refreshes geosite.dat / geoip.dat so adblock rules stay current.
# Runs forever in the background; exits only if container stops.
set -e

DATA_DIR="${DATA_DIR:-/app}"
INTERVAL="${GEO_UPDATE_INTERVAL:-86400}"   # default 24h
URL_BASE="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download"

echo "[geo-update] started (interval=${INTERVAL}s)"

while true; do
    updated=0
    if [ -w "${DATA_DIR}/geosite.dat" ]; then
        if curl -fsSL --max-time 120 -o "${DATA_DIR}/geosite.dat.new" "${URL_BASE}/geosite.dat"; then
            mv "${DATA_DIR}/geosite.dat.new" "${DATA_DIR}/geosite.dat"
            echo "[geo-update] geosite.dat updated $(date -u +%FT%TZ)"
            updated=1
        else
            echo "[geo-update] geosite.dat update failed, keeping old"
            rm -f "${DATA_DIR}/geosite.dat.new"
        fi
    fi
    if [ -w "${DATA_DIR}/geoip.dat" ]; then
        if curl -fsSL --max-time 120 -o "${DATA_DIR}/geoip.dat.new" "${URL_BASE}/geoip.dat"; then
            mv "${DATA_DIR}/geoip.dat.new" "${DATA_DIR}/geoip.dat"
            echo "[geo-update] geoip.dat updated $(date -u +%FT%TZ)"
            updated=1
        else
            echo "[geo-update] geoip.dat update failed, keeping old"
            rm -f "${DATA_DIR}/geoip.dat.new"
        fi
    fi
    # If anything changed, ask the Xray supervisor to restart Xray so the new
    # geo files take effect (Xray caches them at startup).
    if [ "${updated}" = "1" ] && [ -f /tmp/xray-supervisor.pid ]; then
        kill -USR1 "$(cat /tmp/xray-supervisor.pid)" 2>/dev/null && \
            echo "[geo-update] notified xray supervisor to reload"
    fi
    sleep "${INTERVAL}"
done
