FROM debian:latest

# Install required dependencies
RUN apt-get update && apt-get install -y \
    curl wget tar htop net-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Script to fetch, extract, set permissions, and run the provider in background
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

