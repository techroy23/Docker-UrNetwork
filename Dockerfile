FROM alpine:latest

ARG TARGETARCH 

WORKDIR /app

RUN apk update && apk add --no-cache \
    tzdata iputils vnstat dos2unix \
    jq tar curl htop wget procps \
    iptables net-tools bind-tools \
    busybox-extras ca-certificates \
    ca-certificates-bundle bash \
  && rm -rf /var/cache/apk/*

# Use BuildKit secret mount to keep the token out of image layers
RUN --mount=type=secret,id=gh_token \
    set -eux; \
    # read the secret (do NOT print it)
    GH_TOKEN="$(cat /run/secrets/gh_token)"; \
    download_api() { \
      repo="$1"; \
      suffix="$2"; \
      API="https://api.github.com/repos/urnetwork/${repo}/releases/latest"; \
      # use authenticated requests to avoid rate limits
      release_url=$(curl -s -H "Authorization: Bearer ${GH_TOKEN}" "$API" | jq -r '.url'); \
      echo "${suffix} release URL: $release_url"; \
      release_json=$(curl -s -H "Authorization: Bearer ${GH_TOKEN}" "$release_url"); \
      # if GitHub returned an error message, fail with it
      if echo "$release_json" | jq -e 'has("message")' >/dev/null 2>&1; then \
        echo "GitHub API error for ${repo}: $(echo "$release_json" | jq -r .message)"; \
        exit 1; \
      fi; \
      download_url=$(echo "$release_json" | jq -r '.assets[] | select(.name | startswith("urnetwork-provider-")) | .browser_download_url'); \
      if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then \
        echo "No provider asset found for ${repo}"; \
        exit 1; \
      fi; \
      echo "Download URL: $download_url"; \
      filename=$(basename "$download_url"); \
      curl -fSL -k -A "Mozilla/5.0" -o "$filename" "$download_url"; \
      echo "Downloaded: $filename"; \
      echo "$filename $suffix" >> download_list.txt; \
    }; \
    \
    extract_providers() { \
      filename="$1"; \
      suffix="$2"; \
      mkdir -p /app; \
      tar --warning=no-unknown-keyword --extract --file="$filename" --strip-components=2 "linux/amd64/provider" -O > "/app/urnetwork_amd64_${suffix}"; \
      chmod +x "/app/urnetwork_amd64_${suffix}"; \
      echo "Extracted amd64 provider → /app/urnetwork_amd64_${suffix}"; \
      tar --warning=no-unknown-keyword --extract --file="$filename" --strip-components=2 "linux/arm64/provider" -O > "/app/urnetwork_arm64_${suffix}"; \
      chmod +x "/app/urnetwork_arm64_${suffix}"; \
      echo "Extracted arm64 provider → /app/urnetwork_arm64_${suffix}"; \
      rm -f "$filename"; \
      echo "Deleted archive: $filename"; \
    }; \
    \
    download_api "connect" "stable"; \
    download_api "build" "nightly"; \
    \
    while read -r filename suffix; do \
      extract_providers "$filename" "$suffix"; \
    done < download_list.txt; \
    rm -f download_list.txt

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

COPY version.txt entrypoint.sh start_stable.sh start_nightly.sh urnetwork_ipinfo.sh /app/
COPY stats /app/cgi-bin/

RUN dos2unix /app/*.sh /app/cgi-bin/stats

RUN chmod +x /app/*.sh /app/cgi-bin/stats

ENTRYPOINT ["/app/entrypoint.sh"]
