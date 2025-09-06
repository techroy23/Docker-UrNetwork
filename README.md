# Docker-UrNetwork Releases v2025.9.2-720303010
A minimal Docker setup that automatically fetches, updates, and runs the latest urNetwork Provider. The container is built on **Alpine Linux**, ensuring a minimal footprint. Includes built-in authentication handling, resilient restarts, scheduled in-container updates, and network diagnostics.
   
## Features  
- Automated retrieval of the latest urNetwork Provider binary on startup
- Secure credential management via environment variables
- Alpine-based image for minimal footprint
- Persistent storage of authentication tokens and version metadata
- Scheduled update watcher (default at 12:00 Asia/Manila)
- Resilient provider execution with automatic retries and re-authentication
- Built-in network diagnostic script (ipinfo.sh)

## Prerequisites
- Docker Engine
- A valid urNetwork account (USER_AUTH and PASSWORD)

## Run
```sh

# Option 1 : amd64 build
docker run -d --platform linux/amd64 \
  --name="urnetwork-main"
  --cap-add NET_ADMIN \
  -e USER_AUTH="Your-Email@here.com" \
  -e PASSWORD="YourPassword" \
  -v /path/to/your/proxy.txt:/app/proxy.txt \
  ghcr.io/techroy23/docker-urnetwork:latest

# Option 2 : arm64 build
docker run -d --platform linux/arm64 \
  --name="urnetwork-main"
  --cap-add NET_ADMIN \
  -e USER_AUTH="Your-Email@here.com" \
  -e PASSWORD="YourPassword" \
  -v /path/to/your/proxy.txt:/app/proxy.txt \
  ghcr.io/techroy23/docker-urnetwork:latest

# (Optional) Mount a proxy configuration file from host to container.
# Replace /path/to/your/proxy.txt with the absolute path on your host.
# Inside the container it will appear at /app/proxy.txt for automatic detection.
# Omit this line entirely if you don't want to use a proxy.

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
