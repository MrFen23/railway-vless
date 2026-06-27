# Railway VLESS VPN

Personal **VLESS + WebSocket** VPN server on **Xray-core**, deployed to
[Railway](https://railway.app) from GitHub.

Architecture (all in one container):

```
nginx :$PORT  (public, Railway proxies 443 -> $PORT)
  ├── /<WS_PATH>   → Xray (WebSocket upgrade)   [secret]
  ├── /<QR_PATH>   → QR page + clickable link    [secret]
  └── /            → fake "Welcome to nginx" site [fallback]
xray :10000 (internal 127.0.0.1, not exposed)
geo-update loop (refreshes geosite/geoip every 24h)
```

> Railway terminates TLS (HTTPS / WSS) on its side and proxies to the container,
> so traffic between you and the server is fully encrypted over the public internet.

## Repo contents

| File                    | Purpose                                                                |
| ----------------------- | --------------------------------------------------------------------- |
| `Dockerfile`            | Pulls Xray-core `v26.3.27` + geo bases; installs nginx.               |
| `config-template.json`  | Xray config (internal :10000, multi-UUID, sockopt, adblock routing).  |
| `nginx.conf`            | Front router: WS-path → Xray, QR-path → QR page, else fallback site.  |
| `entrypoint.sh`         | Renders configs from env vars, supervises geo-update + Xray + nginx.  |
| `geo-update.sh`         | Background loop: refreshes geosite.dat / geoip.dat every 24h.         |
| `www/qr.html`           | QR page with clickable `vless://` link (inline QR generator).         |
| `www/fallback.html`     | Fake nginx welcome page served for any non-matching request.          |

## Deploy on Railway

1. Push this repo to GitHub.
2. Railway → **New Project → Deploy from GitHub repo**.
3. Railway auto-detects the `Dockerfile`. Set **Variables**:

   | Variable             | Required | Example / default                                   |
   | -------------------- | -------- | --------------------------------------------------- |
   | `UUIDS`              | **yes**  | `uuid1,uuid2,uuid3` (comma-separated)               |
   | `DOMAIN`             | recommended | `myapp.up.railway.app` (your Railway domain)     |
   | `WS_PATH`            | no       | random `/abc12xyz` if unset (secret WS path)        |
   | `QR_PATH`            | no       | random `/abc12xyz` if unset (secret QR page URL)    |
   | `PORT`               | no       | `8080` (Railway also provides this automatically)   |
   | `GEO_UPDATE_INTERVAL`| no       | `86400` seconds (24h)                               |

   > `UUIDS` accepts multiple UUIDs so you can give each person their own access
   > and revoke one without changing the others. `UUID` is still accepted for
   > backward compatibility.

4. **Settings → Networking → Generate Domain** → copy the hostname (e.g.
   `myapp.up.railway.app`) and paste it back into the `DOMAIN` variable, then
   redeploy. The QR page and share link are built from `DOMAIN`.

5. Wait for the deploy to turn green.

## Get your connection

1. Open your secret QR URL in a browser:
   `https://<DOMAIN><QR_PATH>` — e.g. `https://myapp.up.railway.app/qr-abc123`
2. Scan the QR with **v2rayN / Hiddify / Happ / Nekobox / V2RayNG**, **or**
   click the button to open the `vless://` link, **or** copy the link manually.

The share link looks like:
```
vless://<uuid>@<DOMAIN>:443?encryption=none&security=tls&sni=<DOMAIN>&type=ws&host=<DOMAIN>&path=<WS_PATH_ENC>#Railway-VLESS
```

| Field       | Value                         |
| ----------- | ----------------------------- |
| Protocol    | VLESS                         |
| Address     | `<DOMAIN>`                    |
| Port        | `443`                         |
| UUID        | one of `UUIDS`                |
| Encryption  | `none`                        |
| Network     | `ws` (WebSocket)              |
| TLS         | `tls` (handled by Railway)    |
| SNI / Host  | `<DOMAIN>`                    |
| Path        | `<WS_PATH>` (secret)          |

> The secrets (`WS_PATH`, `QR_PATH`) are printed in the deploy logs at startup
> so you can recover them if you didn't set them explicitly.

## Notes

- **Fallback site**: visiting the domain in a browser (without the secret path)
  shows a generic nginx page — the server doesn't look like a proxy.
- **Adblock**: requests to ad/tracker domains are blackholed by Xray routing
  using `geosite:category-ads-*` + a curated domain list. YouTube in-app ads
  are **not** blocked (they share domains with video traffic) — use uBlock
  Origin / Brave / ReVanced on the client for that.
- **Region**: set Railway service region to the closest one (e.g.
  `europe-west1` Frankfurt) for lower latency.
- **Rotate access**: change `UUIDS` and redeploy.
- **Upgrade Xray**: bump `XRAY_VERSION` in the `Dockerfile` and redeploy.
