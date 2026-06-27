# Multi-stage build: download Xray binary + geo databases in a throw-away layer.
FROM alpine:3.20 AS fetcher

ARG XRAY_VERSION=v26.3.27
ARG XRAY_ASSET=Xray-linux-64.zip

WORKDIR /dl
RUN apk add --no-cache curl unzip ca-certificates \
 && curl -fsSL -o xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/${XRAY_ASSET}" \
 && unzip -o xray.zip -d out \
 && chmod +x out/xray \
 && echo "Downloading geosite/geoip rules (Loyalsoldier)..." \
 && curl -fsSL -o out/geosite.dat \
    "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" \
 && curl -fsSL -o out/geoip.dat \
    "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"

# --- runtime image ---
FROM alpine:3.20
LABEL maintainer="MrFen23"
LABEL description="VLESS + WebSocket VPN server for Railway (nginx front + Xray back)"

RUN apk add --no-cache ca-certificates tzdata nginx curl \
 && adduser -D -H xray

WORKDIR /app
COPY --from=fetcher /dl/out/xray        /app/xray
COPY --from=fetcher /dl/out/geosite.dat /app/geosite.dat
COPY --from=fetcher /dl/out/geoip.dat   /app/geoip.dat
COPY config-template.json /app/config-template.json
COPY nginx.conf           /app/nginx.conf
COPY entrypoint.sh        /app/entrypoint.sh
COPY geo-update.sh        /app/geo-update.sh
COPY xray-supervisor.sh   /app/xray-supervisor.sh
COPY www/                 /app/www/

RUN chmod +x /app/xray /app/entrypoint.sh /app/geo-update.sh /app/xray-supervisor.sh \
 && chown -R xray:xray /app

# nginx needs writable locations. Use explicit dirs instead of granting /tmp.
RUN mkdir -p /run /var/lib/nginx/logs /var/lib/nginx/tmp \
             /var/cache/nginx /var/log/nginx \
             /tmp/nginx_client /tmp/nginx_proxy /tmp/nginx_fastcgi \
             /tmp/nginx_uwsgi /tmp/nginx_scgi \
 && chown -R xray:xray /run /var/lib/nginx /var/cache/nginx /var/log/nginx \
                       /tmp/nginx_client /tmp/nginx_proxy /tmp/nginx_fastcgi \
                       /tmp/nginx_uwsgi /tmp/nginx_scgi

USER xray
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
