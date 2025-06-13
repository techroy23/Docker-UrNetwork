# -----------------------------------------------------------------------------
# Base image
# We pick the super-minimal Alpine Linux
# to keep our final container tiny.
# -----------------------------------------------------------------------------
FROM alpine:latest

# -----------------------------------------------------------------------------
# Install essential packages
# - apk update          : refresh package index
# - apk add --no-cache  : install WITHOUT persisting cache
#   • curl, wget        : HTTP tools (GitHub API + file downloads)
#   • ca-certificates   : TLS trust store (HTTPS won’t work without it!)
#   • tar               : unpack .tar.gz releases
#   • htop, net-tools…  : optional debugging utils (nice during dev shells)
# Finally we nuke /var/cache/apk to shave off a few megabytes.
# -----------------------------------------------------------------------------
RUN apk update && apk add --no-cache \
    curl \
    ca-certificates \
    wget \
    tar \
    htop \
    net-tools \
    procps \
    iputils \
  && rm -rf /var/cache/apk/*

# -----------------------------------------------------------------------------
# Set working directory
# Every subsequent RUN/CMD/COPY uses /app as CWD.
# -----------------------------------------------------------------------------
WORKDIR /app

# -----------------------------------------------------------------------------
# ↓↓↓  Fetch latest provider binary  ↓↓↓
# Why do this here (build-time) instead of in entrypoint?
# • Guarantees reproducible image: once built, the binary is baked in.
# • Container boots instantly (no “download on startup” hit).
# -----------------------------------------------------------------------------
RUN set -eux; \
    \
    # Query the GitHub API for the newest release JSON
    echo "Fetching latest release…"; \
    release_json="$(curl -sL https://api.github.com/repos/urnetwork/build/releases/latest)"; \
    \
    # Extract the .tar.gz download URL from the JSON
    tar_url="$(echo "$release_json" \
      | grep '"browser_download_url":' \
      | grep '.tar.gz"' \
      | cut -d '"' -f 4)"; \
    echo "Downloading: $tar_url"; \
    \
    # Pull the archive
    wget -q "$tar_url" -O provider.tar.gz; \
    \
    # Map Alpine CPU arch ➜ upstream binary arch
    alpine_arch="$(apk --print-arch)"; \
    case "$alpine_arch" in \
        x86_64) urn_arch=amd64 ;; \
        aarch64) urn_arch=arm64 ;; \
        *) echo "❌ Unsupported architecture: $alpine_arch" && exit 1 ;; \
    esac; \
    \
    # Unpack ONLY the binary we need, discard the rest
    #     --strip-components=2 removes the leading “linux/$urn_arch/”
    tar -xzf provider.tar.gz --strip-components=2 linux/$urn_arch/provider; \
    \
    # Make it executable, then clean up to keep layers small
    chmod +x provider; \
    rm provider.tar.gz

# -----------------------------------------------------------------------------
# Entry point script
# We copy our tiny shell wrapper that will eventually `exec ./provider`.
# -----------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# -----------------------------------------------------------------------------
# Default container start command
# -----------------------------------------------------------------------------
ENTRYPOINT ["sh", "/entrypoint.sh"]
