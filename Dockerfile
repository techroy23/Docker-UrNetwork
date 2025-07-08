FROM alpine:latest

RUN apk update && apk add --no-cache \
    jq tar curl htop wget procps \
    tzdata iputils dos2unix \
    iptables net-tools bind-tools \
    ca-certificates \
  && rm -rf /var/cache/apk/*

WORKDIR /app

RUN set -eux; \
    echo "Fetching latest release…"; \
    release_json="$(curl -sL https://api.github.com/repos/urnetwork/build/releases/latest)"; \
    tar_url="$(echo "$release_json" \
      | grep '"browser_download_url":' \
      | grep '.tar.gz"' \
      | cut -d '"' -f 4)"; \
    echo "Downloading: $tar_url"; \
    wget -q "$tar_url" -O provider.tar.gz; \
    alpine_arch="$(apk --print-arch)"; \
    case "$alpine_arch" in \
        x86_64) urn_arch=amd64 ;; \
        aarch64) urn_arch=arm64 ;; \
        *) echo "❌ Unsupported architecture: $alpine_arch" && exit 1 ;; \
    esac; \
    tar -xzf provider.tar.gz --strip-components=2 linux/$urn_arch/provider; \
    chmod +x provider; \
    rm provider.tar.gz

RUN mkdir -p /root/.urnetwork
VOLUME ["/root/.urnetwork"]

COPY entrypoint.sh /entrypoint.sh
COPY ipinfo.sh /app/ipinfo.sh
COPY version.txt /app/version.txt

RUN dos2unix /entrypoint.sh
RUN dos2unix /app/ipinfo.sh

RUN chmod +x /entrypoint.sh
RUN chmod +x /app/ipinfo.sh

ENTRYPOINT ["/entrypoint.sh"]