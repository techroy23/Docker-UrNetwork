# Docker-UrNetwork Releases v2025.10.27-768046850
A minimal Docker setup that automatically fetches, updates, and runs the latest urNetwork Provider. The container is built on **Alpine Linux**, ensuring a minimal footprint. Includes built-in authentication handling, resilient restarts, scheduled in-container updates, and network diagnostics.

## Links
| DockerHub | GitHub | Invite |
|----------|----------|----------|
| [![Docker Hub](https://img.shields.io/badge/ㅤ-View%20on%20Docker%20Hub-blue?logo=docker&style=for-the-badge)](https://hub.docker.com/r/techroy23/docker-urnetwork) | [![GitHub Repo](https://img.shields.io/badge/ㅤ-View%20on%20GitHub-black?logo=github&style=for-the-badge)](https://github.com/techroy23/Docker-UrNetwork) | [![Invite Link](https://img.shields.io/badge/ㅤ-Join%20UrNetwork%20Now-brightgreen?logo=linktree&style=for-the-badge)](https://ur.io/c?bonus=0MYG84) |

## Features
- Automated retrieval of the latest urNetwork Provider binary on startup
- Secure credential management via environment variables
- Alpine-based image for minimal footprint
- Persistent storage of authentication tokens and version metadata
- Scheduled update watcher (default at 12:00 Asia/Manila)
- Resilient provider execution with automatic retries and re-authentication
- Built-in network diagnostic script (ipinfo.sh)

## Environment variables
| Variable | Requirement | Description |
|----------|-------------|-------------|
| `EMAIL`  | Required    | Your Email. Container exits if not provided. |
| `PASSWORD`  | Required    | Your Password. Container exits if not provided. |
| `ENABLE_IP_CHECKER` | Optional | Boolean true/false : Checks and prints your public IPv4 address to stdout visible directly in Docker logs for easy monitoring. |
| `-v /path/to/your/proxy.txt:/app/proxy.txt`  | Optional | Mount a proxy configuration file from host to container.<br>Omit this line entirely if you don't want to use a proxy.<br>The proxy inside the proxy.txt should have this format ip:port:username:password.<br>See the sample below. one proxy per line. |
| | Optional | `123.456.789.012:55555:myproxyusername:myproxypassword`<br>`234.567.890.123:44444:myproxyusername:myproxypassword`<br>`345.678.901.234:33333:myproxyusername:myproxypassword`<br>`456.789.012.345:22222:myproxyusername:myproxypassword`<br>`567.890.123.456:11111:myproxyusername:myproxypassword` |
| `-v vnstat_data:/var/lib/vnstat`<br>`-p 8080:8080` | Optional | Stats JSON Portal = `http://localhost:port/cgi-bin/stats` <br>Mounts a docker volume `vnstat_data` to `/var/lib/vnstat`. <br>Mounting it ensures data history persists across restarts or image updates. <br>Each instance needs its own volume and port to avoid overwriting each other’s data.<br>See the sample below. |
| | Optional | `-v vnstat_data1:/var/lib/vnstat`  # for first container <br>`-p 9001:8080   # Host port 8081`  # for first container <br>`-v vnstat_data2:/var/lib/vnstat`  # for second container <br>`-p 9002:8080   # Host port 9000`  # for second container |

## Run
```sh
# Option 1 : amd64 build
docker run -d --platform linux/amd64 \
  --name="urnetwork" \
  --restart="always" \
  --pull="always" \
  --privileged \
  --log-driver=json-file \
  --log-opt max-size=5m \
  --log-opt max-file=3 \
  -e USER_AUTH="example@gmail.com" \
  -e PASSWORD="mYv3rYsEcUr3dP@sSw0rD" \
  -e ENABLE_IP_CHECKER=false \
  -v /path/to/your/proxy.txt:/app/proxy.txt \
  -v vnstat_data:/var/lib/vnstat \
  -p 8080:8080 \
  ghcr.io/techroy23/docker-urnetwork:latest

# Option 2 : arm64 build
docker run -d --platform linux/arm64 \
  --name="urnetwork" \
  --restart="always" \
  --pull="always" \
  --privileged \
  --log-driver=json-file \
  --log-opt max-size=5m \
  --log-opt max-file=3 \
  -e USER_AUTH="example@gmail.com" \
  -e PASSWORD="mYv3rYsEcUr3dP@sSw0rD" \
  -e ENABLE_IP_CHECKER=false \
  -v /path/to/your/proxy.txt:/app/proxy.txt \
  -v vnstat_data:/var/lib/vnstat \
  -p 8080:8080 \
  techroy23/docker-urnetwork:latest
```

## Promo Video
<div align="center">
  <a href="https://www.youtube.com/watch?v=E1tXbiLSU2I">
    <img src="https://img.youtube.com/vi/E1tXbiLSU2I/0.jpg" alt="Watch the Video">
  </a>
</div>

## Promo
<ul><li><a href="https://ur.io/c?bonus=0MYG84"> [ REGISTER HERE ] </a></li></ul>
<div align="center">
  <a href="https://ur.io/c?bonus=0MYG84">
    <img src="screenshot/img0.png" alt="Alt text">
  </a>
</div>
