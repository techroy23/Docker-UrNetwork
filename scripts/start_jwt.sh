
#!/bin/sh
# URNetwork Provider Entrypoint Script
# ------------------------------------
# This script bootstraps the URNetwork provider inside a container.
# Responsibilities:
#   - Configure proxy if provided
#   - Detect system architecture
#   - Optionally check public IP
#   - Start vnStat monitoring and lightweight HTTP server

# Exit immediately if any command fails
set -e

# === Configuration Variables ===
APP_DIR="/app"
JWT_FILE="/root/.urnetwork/jwt"
ENABLE_VNSTAT="${ENABLE_VNSTAT:-true}"
ENABLE_IP_CHECKER="${ENABLE_IP_CHECKER:-false}"
IP_CHECKER_URL="https://raw.githubusercontent.com/techroy23/IP-Checker/refs/heads/main/app.sh"

# === Logging Helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') >>> An2Kin >>> $*"
}

# === Directory Validation ===
func_check_dir() {
    [ -d "$APP_DIR" ] || {
        log "[ERROR] APP_DIR '$APP_DIR' does not exist." >&2
        exit 1
    }
    cd "$APP_DIR" || {
        log "[ERROR] cannot cd to '$APP_DIR'." >&2
        exit 1
    }
}

# === Proxy Setup ===
func_check_proxy() {
    log "Checking proxy configuration"
    ls -la ~/.urnetwork/ 2>/dev/null || log "~/.urnetwork/ not found"
    rm -f ~/.urnetwork/proxy
    if [ -f "/app/proxy.txt" ]; then
        log "proxy.txt found; adding proxy"
		PROVIDER_BIN="$APP_DIR/urnetwork_${A_SYS_ARCH}_stable"
        "$PROVIDER_BIN" proxy add --proxy_file="/app/proxy.txt"
    else
        log "No proxy.txt found; skipping proxy"
    fi
}

# === Architecture Detection ===
func_get_architecture() {
    case "$(uname -m)" in
      x86_64)  A_SYS_ARCH=amd64  ;;
      aarch64) A_SYS_ARCH=arm64  ;;
      *)
        log "Unsupported arch $(uname -m)" >&2
        exit 1
        ;;
    esac
}

# === Public IP Checker ===
func_get_ip() {
  if [ "$ENABLE_IP_CHECKER" = "true" ]; then
    log "Checking current public IP..."
    if curl -fsSL "$IP_CHECKER_URL" | sh; then
      log "IP checker script ran successfully"
    else
      log "WARNING: Could not fetch or execute IP checker script"
    fi
  else
    log "IP checker disabled"
  fi
}

# === vnStat Monitoring Setup ===
func_start_vnstat() {
    VNSTAT_LC="$(printf '%s' "$ENABLE_VNSTAT" | tr '[:upper:]' '[:lower:]')"
    if [ "$VNSTAT_LC" = "true" ]; then
        if [ -f /var/lib/vnstat/vnstat.db ]; then
            log "vnStat DB already exists (SQLite backend)"
        elif [ -f /var/lib/vnstat/.config ]; then
            log "vnStat DB already exists (binary backend)"
        else
            log "Initializing vnStat database"
            vnstatd --initdb
        fi
        vnstatd -d --alwaysadd >/dev/null 2>&1
        log "vnstatd started"
        httpd -f -p 8080 -h /app &
        log "HTTP server started on container port 8080"
    else
        log "VNSTAT disabled ..."
    fi
}

# === Provider Lifecycle Management ===
func_start_provider(){
    log "Starting UrNetwork ..."
    PROVIDER_BIN="$APP_DIR/urnetwork_${A_SYS_ARCH}_stable"
    BIN_VER="$($PROVIDER_BIN --version)"
    log "Running UrNetwork build v${BIN_VER}"

    if [ "$#" -eq 0 ]; then
        log "No JWT token provided, showing help..."
        "$PROVIDER_BIN" --help
        return 1
    elif [ "$#" -ne 1 ]; then
        log "ERROR: Expected exactly 1 JWT token argument, got $#"
        return 1
    fi

    JWT_TOKEN="$1"

    "$PROVIDER_BIN" provide auth-provide "$JWT_TOKEN"
    code=$?

    if [ "$code" -eq 0 ]; then
        log "UrNetwork exited cleanly."
    else
        log "UrNetwork exited with code=$code"
    fi
}

# === Bootstrap Sequence ===
func_bootstrap() {
    sh /app/urnetwork_ipinfo.sh
	func_get_architecture
	func_check_dir
    func_check_proxy
    func_get_ip
    func_start_vnstat
    func_start_provider "$@"
}

# === Main Entrypoint ===
main() {
    func_bootstrap "$@"
}

main "$@"
