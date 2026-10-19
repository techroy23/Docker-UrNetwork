# Docker-UrNetwork
A minimal Docker setup that automatically fetches, updates, and runs the latest urNetwork Provider.  The container is built on **Alpine Linux**, ensuring a minimal footprint. Includes built-in authentication handling, resilient restarts, scheduled in‑container updates (nightly build), and a built-in provider status endpoint.  

> **Payout wallet — highly advised:** set your earning wallet in the **UrNetwork mobile app or website** before expecting rewards. This container does not configure wallet consent; a registered provider without a wallet is not paid.

## Build
- UrNetwork_nightly v2026.10.18-1075514170

## Links
| DockerHub | GitHub | Invite |
|----------|----------|----------|
| [![Docker Hub](https://img.shields.io/badge/ㅤ-View%20on%20Docker%20Hub-blue?logo=docker&style=for-the-badge)](https://hub.docker.com/r/techroy23/docker-urnetwork) | [![GitHub Repo](https://img.shields.io/badge/ㅤ-View%20on%20GitHub-black?logo=github&style=for-the-badge)](https://github.com/techroy23/Docker-UrNetwork) | [![Invite Link](https://img.shields.io/badge/ㅤ-Join%20UrNetwork%20Now-brightgreen?logo=linktree&style=for-the-badge)](https://ur.io/c?bonus=0MYG84) |

## Features
- Automated retrieval of the latest urNetwork Provider binary on startup (nightly build)
- Daily in‑container update at **00:00 UTC** (configurable with `UPDATE_TIME`)
- Two auth modes: `userpass` (email/password) and `authcode`
- Reuses a valid JWT and only re‑authenticates when the token is missing, expired or rejected
- Persistent provider identity, credentials and version metadata
- Built‑in provider status JSON on port `8080` (no separate vnStat/httpd)
- Resilient provider execution with automatic retries
- Optional proxy, all‑operators and auto‑register support

## Environment variables
| Variable | Requirement | Description |
|:--------:|:-----------:|-------------|
| `-e AUTH='userpass'`<br />`-e AUTH='authcode'` | Optional | **userpass** Log in with `USER_AUTH` and `PASSWORD` and keep the provider running.<br /><br />**authcode** Log in with an auth code from https://ur.io/ (`AUTHCODE` or the container argument).<br /><br />Default is **userpass** |
| `-e USER_AUTH <EMAIL>`<br />and<br />`-e PASSWORD <PASSWORD>` | Required for<br />**userpass** | Your Email and Password.<br />The container will exit if not provided. |
| `-e AUTHCODE <AUTH-CODE>` | Required for<br />**authcode** | Your authentication code.<br />The container will exit if not provided.<br />Generate one here: https://ur.io/ |
| `-e API_URL`<br />and<br />`-e CONNECT_URL` | Optional | Custom operator endpoints, for example `API_URL='https://api.example.net'` and `CONNECT_URL='wss://connect.example.net'`.<br />Passed as `--api_url` and `--connect_url` to both `auth` and `provide`.<br />**Set both or neither** — if only one is set the container exits instead of starting.<br />Ignored with a warning when `ALL_OPERATORS=Y`, because each operator uses its own endpoints.<br />Default is empty (the binary defaults to the public operator). |
| `-e MAX_MEMORY` | Optional | Soft memory target passed as `--max-memory`, for example `1gib`.<br />Default is empty (the binary picks a target from host memory). |
| `-e VERBOSE` | Optional | Provider log verbosity: `0` off, `1` for `-v`, `2` for `-vv`.<br />Default is **0**. |
| `-e PROVIDER_PORT` | Optional | Provider status JSON port, passed as `--port`. `http://localhost:8080/` returns version/status/diagnostics.<br />Set to `0` to disable the status server.<br />Default is **8080**. |
| `-e ALL_OPERATORS` | Optional | **Y**/**N**. `Y` passes `--all-operators` and mines every operator in `https://ur.xyz/operators.yml`, with a separate state directory per operator.<br />`N` mines the default operator only.<br />Default is **N**. |
| `-e AUTO_REGISTER` | Optional | **Y**/**N**. Only used with `ALL_OPERATORS=Y`. Passes `--auto-register`, which implies `--allow-client-registration`, and requires `HOTKEY_SEED_FILE`.<br />Default is **N**. |
| `-e HOTKEY_SEED_FILE` | Required for<br />`AUTO_REGISTER=Y` | Absolute path inside the container to an sr25519 hotkey seed file (32 raw bytes or 64 hex characters). The provider never creates this file. |
| `-e ALLOW_CLIENT_REGISTRATION` | Optional | **auto**/**Y**/**N**. Controls `--allow-client-registration`.<br /><br />**auto** adds the flag only when `/root/.urnetwork` has no provider identity yet (a genuinely new install).<br />**Y** always adds it.<br />**N** never adds it.<br /><br />Default is **auto**. |
| `-e PROVIDER_ARGS` | Optional | Extra flags passed to `provide`, for example `--adopt-legacy-provider-key` or `--max-memory=1gib`.<br />Default is empty. |
| `-e UPDATE_TIME` | Optional | Time of the daily in‑container update, `HH:MM` in **UTC**.<br />Default is **00:00**. |
| `-v urnetwork_data:/root/.urnetwork` | Recommended | Persists the provider identity, JWT and registration state.<br />Without it, every new container becomes a new provider identity and loses its registration. |
| `-v /path/to/your/proxy.txt:/app/proxy.txt`  | Optional | Mount a proxy configuration file from host to container.<br />Omit this line entirely if you don't want to use a proxy.<br />The proxy inside the proxy.txt should have this format ip:port:username:password.<br />See the sample below. one proxy per line. |
| | Optional | `123.456.789.012:55555:myproxyusername:myproxypassword`<br />`234.567.890.123:44444:myproxyusername:myproxypassword`<br />`345.678.901.234:33333:myproxyusername:myproxypassword`<br />`456.789.012.345:22222:myproxyusername:myproxypassword`<br />`567.890.123.456:11111:myproxyusername:myproxypassword` |
| `-p 8080:8080` | Optional | Provider status JSON = `http://localhost:8080/`.<br />Exposing it publicly reveals provider diagnostics; restrict it to your monitoring network.<br />Set `PROVIDER_PORT=0` to disable it. |

## When to turn each flag on or off
| Flag | Default | Turn it ON when | Turn it OFF when |
|------|---------|-----------------|------------------|
| `ALLOW_CLIENT_REGISTRATION` | `auto` | A brand new install with an empty `/root/.urnetwork` (auto already does this), or you intentionally want a new provider identity/slot. | Restoring an existing installation or any normal restart. Leaving it `auto` is correct for both cases. |
| `ALL_OPERATORS` | `N` | You want one container to serve every operator in the published list. Each operator gets its own identity under `~/.urnetwork/operators/<domain>/`. | You want a single provider identity on the default operator (normal setup). |
| `AUTO_REGISTER` | `N` | You use `ALL_OPERATORS=Y` and want each newly listed operator registered automatically from a Bittensor hotkey (`HOTKEY_SEED_FILE` required). | You do not use `ALL_OPERATORS`, or you authenticate operators with your account instead. |
| `PROVIDER_PORT` | `8080` | You want the built-in status/diagnostics JSON. | The port would be publicly reachable, or you do not need monitoring. Use `0`. |
| `API_URL` + `CONNECT_URL` | unset | You serve a non-default operator. Set **both** together. | You use the public default operator (normal setup). |
| `MAX_MEMORY` | unset | The host has a memory limit and you want the provider to stay under it, e.g. `1gib`. | You want the binary to size itself from host memory. |
| `VERBOSE` | `0` | You are debugging startup/connection problems. | Normal operation. |

## Run with username/password
```sh
# Option 1 : amd64 build
docker run -d --platform linux/amd64 \
  --name=urnetwork \
  --pull=always --restart=always \
  --log-driver=json-file --log-opt max-size=1m --log-opt max-file=1 \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --sysctl net.ipv4.ip_forward=1 \
  -e AUTH='userpass' \
  -e USER_AUTH='example@gmail.com' \
  -e PASSWORD='mYv3rYsEcUr3dP@sSw0rD' \
  -v /path/to/your/proxy.txt:/app/proxy.txt \
  -v urnetwork_data:/root/.urnetwork \
  -p 8080:8080 \
  techroy23/docker-urnetwork:latest

# Option 2 : arm64 build
docker run -d --platform linux/arm64 \
  --name=urnetwork \
  --pull=always --restart=always \
  --log-driver=json-file --log-opt max-size=1m --log-opt max-file=1 \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --sysctl net.ipv4.ip_forward=1 \
  -e AUTH='userpass' \
  -e USER_AUTH='example@gmail.com' \
  -e PASSWORD='mYv3rYsEcUr3dP@sSw0rD' \
  -v /path/to/your/proxy.txt:/app/proxy.txt \
  -v urnetwork_data:/root/.urnetwork \
  -p 8080:8080 \
  techroy23/docker-urnetwork:latest
```

## Run with auth code
- Replace `<AUTH-CODE>` with the code you generated from https://ur.io/
- The code is only exchanged when no valid JWT exists, so restarts reuse the stored token.
```sh
# Option 1 : amd64 build
docker run -d --platform linux/amd64 \
  --name=urnetwork \
  --pull=always --restart=always \
  --log-driver=json-file --log-opt max-size=1m --log-opt max-file=1 \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --sysctl net.ipv4.ip_forward=1 \
  -e AUTH='authcode' \
  -e AUTHCODE='<AUTH-CODE>' \
  -v /path/to/your/proxy.txt:/app/proxy.txt \
  -v urnetwork_data:/root/.urnetwork \
  -p 8080:8080 \
  techroy23/docker-urnetwork:latest

# Option 2 : arm64 build
docker run -d --platform linux/arm64 \
  --name=urnetwork \
  --pull=always --restart=always \
  --log-driver=json-file --log-opt max-size=1m --log-opt max-file=1 \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --sysctl net.ipv4.ip_forward=1 \
  -e AUTH='authcode' \
  -e AUTHCODE='<AUTH-CODE>' \
  -v /path/to/your/proxy.txt:/app/proxy.txt \
  -v urnetwork_data:/root/.urnetwork \
  -p 8080:8080 \
  techroy23/docker-urnetwork:latest
```

## Run with every listed operator
```sh
docker run -d --platform linux/amd64 \
  --name=urnetwork \
  --pull=always --restart=always \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --sysctl net.ipv4.ip_forward=1 \
  -e AUTH='userpass' \
  -e USER_AUTH='example@gmail.com' \
  -e PASSWORD='mYv3rYsEcUr3dP@sSw0rD' \
  -e ALL_OPERATORS='Y' \
  -v urnetwork_data:/root/.urnetwork \
  -p 8080:8080 \
  techroy23/docker-urnetwork:latest
```
Each operator is authenticated with your account when its token is missing. To register every operator from a Bittensor hotkey instead, add:
```sh
  -e ALL_OPERATORS='Y' \
  -e AUTO_REGISTER='Y' \
  -e HOTKEY_SEED_FILE='/root/.urnetwork/hotkey.seed' \
  -v /path/to/hotkey.seed:/root/.urnetwork/hotkey.seed:ro \
```

## Promo Video
<div align="center">
  <a href="https://www.youtube.com/watch?v=2Oy4X88s9FY">
    <img src="https://img.youtube.com/vi/2Oy4X88s9FY/0.jpg" alt="Watch the Video">
  </a>
</div>

## Promo
<ul><li><a href="https://ur.io/c?bonus=0MYG84"> [ REGISTER HERE ] </a></li></ul>
<div align="center">
  <a href="https://ur.io/c?bonus=0MYG84">
    <img src="screenshot/img0.png" alt="Alt text">
  </a>
</div>
