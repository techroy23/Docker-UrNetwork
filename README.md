# Docker-UrNetwork
A Dockerized setup for automating urNetwork Provider deployment. It fetches the latest release, extracts binaries, manages authentication via environment variables, and runs the provider app in the background. Includes essential system tools for network diagnostics, ensuring efficiency and error-resistant execution in a Debian-based container.

## Features  
- **Automated Provider Deployment**: Fetches and extracts the latest release from GitHub.  
- **Authentication Handling**: Uses environment variables for secure authentication.  
- **Background Execution**: Starts the provider and monitors network activity.  
- **Minimal Manual Intervention**: Designed for efficiency and error-resistant execution.  
- **Network Diagnostics**: Includes tools like `netstat` for monitoring activity.  

## Installation & Usage  
- do not forget to replace "Your-Email@here.com" and "YourPassword"
```bash
docker run -d --platform linux/arm64 -e USER_AUTH="Your-Email@here.com" -e PASSWORD="YourPassword" ghcr.io/techroy23/docker-urnetwork:latest 
docker run -d --platform linux/amd64 -e USER_AUTH="Your-Email@here.com" -e PASSWORD="YourPassword" ghcr.io/techroy23/docker-urnetwork:latest
```

## Promo Video
[![Watch the Video](https://img.youtube.com/vi/E1tXbiLSU2I/0.jpg)](https://www.youtube.com/watch?v=E1tXbiLSU2I)
