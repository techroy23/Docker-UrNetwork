FROM alpine:latest

ARG TARGETARCH 

WORKDIR /app

RUN apk update && apk add --no-cache \
    tzdata iputils vnstat dos2unix \
    jq tar curl htop wget procps \
    iptables net-tools bind-tools \
    busybox-extras ca-certificates \
    ca-certificates-bundle \
  && rm -rf /var/cache/apk/*

RUN set -eux; \
    echo "Fetching latest release…"; \
    release_json="$(curl -sL https://api.github.com/repos/urnetwork/build/releases/latest)"; \
    tar_url="$(echo "$release_json" \
      | grep '"browser_download_url":' \
      | grep 'urnetwork-provider-.*\.tar\.gz"' \
      | cut -d '"' -f 4)"; \
    echo "Downloading: $tar_url"; \
    wget -q "$tar_url" -O provider.tar.gz; \
    if [ "$TARGETARCH" = "amd64" ]; then \
        BIN_TARGET=amd64; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        BIN_TARGET=arm64; \
    else \
        echo "Unsupported architecture: $TARGETARCH" && exit 1; \
    fi; \
    tar -xzf provider.tar.gz --strip-components=2 "linux/$BIN_TARGET/provider"; \
    chmod +x provider; \
    rm provider.tar.gz

RUN sed -i \
  -e 's/^;*TimeSyncWait.*/TimeSyncWait 1/' \
  -e 's/^;*TrafficlessEntries.*/TrafficlessEntries 1/' \
  -e 's/^;*UpdateInterval.*/UpdateInterval 15/' \
  -e 's/^;*PollInterval.*/PollInterval 15/' \
  -e 's/^;*SaveInterval.*/SaveInterval 1/' \
  -e 's/^;*UnitMode.*/UnitMode 1/' \
  -e 's/^;*RateUnit.*/RateUnit 0/' \
  -e 's/^;*RateUnitMode.*/RateUnitMode 0/' \
  /etc/vnstat.conf

RUN mkdir -p /root/.urnetwork
VOLUME ["/root/.urnetwork"]

RUN mkdir -p /app/cgi-bin/
COPY stats /app/cgi-bin/

COPY entrypoint.sh /entrypoint.sh
COPY ipinfo.sh /app/ipinfo.sh
COPY version.txt /app/version.txt

RUN dos2unix /entrypoint.sh
RUN dos2unix /app/ipinfo.sh
RUN dos2unix /app/cgi-bin/stats

RUN chmod +x /entrypoint.sh
RUN chmod +x /app/ipinfo.sh
RUN chmod +x /app/cgi-bin/stats

ENTRYPOINT ["/entrypoint.sh"]

CMD ["bash"]
