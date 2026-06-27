#!/bin/sh
# Supervises the Xray process:
#   - restarts it automatically if it crashes (fix: silent VPN failure)
#   - reloads geo databases on USR1 from geo-update.sh (restarts Xray so new
#     geosite/geoip files take effect — Xray caches them at startup)
set -u

echo $$ > /tmp/xray-supervisor.pid
XPID=""
RELOADING=0

run_xray() {
    /app/xray run -config /app/config.json &
    XPID=$!
}

reload_xray() {
    RELOADING=1
    if [ -n "${XPID}" ]; then
        echo "[xray] geo-update finished — restarting to apply new rules"
        kill "${XPID}" 2>/dev/null
    fi
}
trap reload_xray USR1

echo "[xray] supervisor started (pid $$)"
run_xray

while true; do
    wait "${XPID}" 2>/dev/null
    status=$?

    if [ -f /tmp/xray-stop ]; then
        echo "[xray] stop requested, supervisor exiting"
        break
    fi

    if [ "${RELOADING}" = "1" ]; then
        RELOADING=0
        echo "[xray] restarting after geo reload"
    else
        echo "[xray] process exited (status=${status}), restarting in 3s..." >&2
        sleep 3
    fi
    run_xray
done
