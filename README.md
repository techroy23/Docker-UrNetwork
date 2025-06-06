# Docker-UrNetwork
A Dockerized setup for automating urNetwork Provider deployment. It fetches the latest release, extracts binaries, manages authentication via environment variables, and runs the provider app in the background. Includes essential system tools for network diagnostics, ensuring efficiency and error-resistant execution in a Debian-based container.

## Features  
- **Automated Provider Deployment**: Fetches and extracts the latest release from GitHub.  
- **Authentication Handling**: Uses environment variables `USER_AUTH` and `PASSWORD` for secure authentication.  
- **Minimal Manual Intervention**: Designed for efficiency and error-resistant execution.  
- **Network Diagnostics**: Includes tools like `netstat` for monitoring activity.  

## Run
```bash

# Option 1 : amd64 build
docker run -d --platform linux/amd64 \
  -e USER_AUTH="Your-Email@here.com" \
  -e PASSWORD="YourPassword" \
  --shm-size=2gb \
  ghcr.io/techroy23/docker-urnetwork:latest


# Option 2 : arm64 build
docker run -d --platform linux/arm64 \
  -e USER_AUTH="Your-Email@here.com" \
  -e PASSWORD="YourPassword" \
  --shm-size=2gb \
  ghcr.io/techroy23/docker-urnetwork:latest

```

## Promo Video
<div align="center">
  <a href="https://www.youtube.com/watch?v=E1tXbiLSU2I">
    <img src="https://img.youtube.com/vi/E1tXbiLSU2I/0.jpg" alt="Watch the Video">
  </a>
</div>
