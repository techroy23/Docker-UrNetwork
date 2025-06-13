FROM debian:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl ca-certificates wget tar htop net-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN set -eux; \
    echo "Fetching latest release…"; \
    release_json="$(curl -sL https://api.github.com/repos/urnetwork/build/releases/latest)"; \
    tar_url="$(echo "$release_json" | grep '"browser_download_url":' | grep '.tar.gz"' | cut -d '"' -f 4)"; \
    echo "Downloading: $tar_url"; \
    wget -q "$tar_url" -O provider.tar.gz; \
    \
    deb_arch="$(dpkg --print-architecture)"; \
    case "$deb_arch" in \
        amd64) urn_arch=amd64 ;; \
        arm64) urn_arch=arm64 ;; \
        *) echo "Unsupported architecture: $deb_arch" && exit 1 ;; \
    esac; \
    \
    tar -xzf provider.tar.gz --strip-components=2 linux/$urn_arch/provider; \
    chmod +x provider; \
    rm provider.tar.gz

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
