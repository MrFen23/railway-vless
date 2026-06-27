# Railway VLESS VPN

Personal VLESS + WebSocket VPN server built on **Xray-core**, designed to deploy on
[Railway](https://railway.app) straight from this GitHub repo.

> Railway terminates TLS (HTTPS / WSS) on its side and proxies WebSocket traffic to the
> container, so the connection between you and the server is fully encrypted over the public
> internet — even though the container itself listens on plain WS.

## Repo contents

| File                  | Purpose                                                        |
| --------------------- | ------------------------------------------------------------- |
| `Dockerfile`          | Pulls Xray-core `v26.3.27`, runs as non-root user.           |
| `config-template.json`| Xray config with `{{UUID}}` / `{{PORT}}` placeholders.        |
| `entrypoint.sh`       | Renders the template from env vars at startup, then runs Xray.|
| `.gitignore`          | Keeps generated `config.json` and `.env` out of git.         |

## Deploy on Railway

1. Push this repo to GitHub.
2. Go to <https://railway.app> → **New Project → Deploy from GitHub repo**.
3. Railway auto-detects the `Dockerfile`. Set these **Variables**:

   | Variable | Value                                            |
   | -------- | ----------------------------------------------- |
   | `UUID`   | your UUID, e.g. `7b976e73-9937-49cb-86e9-c3d5508d7933` |
   | `PORT`   | `8080` (Railway also exposes this automatically) |

4. **Settings → Networking → Generate Domain** to get a public HTTPS URL,
   e.g. `https://myapp.up.railway.app`.
5. Wait for the deploy to turn green. Done.

## Client config (VLESS share link)

Build the link from your Railway domain and UUID:

```
vless://7b976e73-9937-49cb-86e9-c3d5508d7933@myapp.up.railway.app:443?encryption=none&security=tls&sni=myapp.up.railway.app&type=ws&host=myapp.up.railway.app&path=%2F#Railway-VLESS
```

Replace `myapp.up.railway.app` with your actual Railway domain. Import into
**v2rayN / Nekobox / Hiddify / V2RayNG / Streisand** and connect.

| Field       | Value                         |
| ----------- | ----------------------------- |
| Protocol    | VLESS                         |
| Address     | `<your>.up.railway.app`       |
| Port        | `443`                         |
| UUID        | same as `UUID` env var        |
| Encryption  | `none`                        |
| Network     | `ws` (WebSocket)              |
| TLS         | `tls` (handled by Railway)    |
| SNI / Host  | `<your>.up.railway.app`       |
| Path        | `/`                           |

## Notes

- Railway free/trial tier sleeps idle apps and limits bandwidth/usage — fine for personal use.
- To rotate access: change `UUID` in Railway Variables and redeploy.
- To upgrade Xray: bump `XRAY_VERSION` in the `Dockerfile` and redeploy.
