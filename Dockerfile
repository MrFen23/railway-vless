# Multi-stage build: download Xray binary in a throw-away layer, then run.
FROM alpine:3.20 AS fetcher

# Pinned Xray-core version (update here to upgrade).
ARG XRAY_VERSION=v26.3.27
ARG XRAY_ASSET=Xray-linux-64.zip

WORKDIR /dl
RUN apk add --no-cache curl unzip ca-certificates \
 && curl -fsSL -o xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/${XRAY_ASSET}" \
 && unzip -o xray.zip -d out \
 && chmod +x out/xray

# --- runtime image ---
FROM alpine:3.20
LABEL maintainer="MrFen23"
LABEL description="VLESS + WebSocket VPN server for Railway"

RUN apk add --no-cache ca-certificates tzdata \
 && adduser -D -H xray

WORKDIR /app
COPY --from=fetcher /dl/out/xray /app/xray
COPY config-template.json /app/config-template.json
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/xray /app/entrypoint.sh

USER xray
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
