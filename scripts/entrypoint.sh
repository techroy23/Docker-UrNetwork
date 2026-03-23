#!/bin/sh
set -e
# Entrypoint script for selecting and starting the build of UrNetwork.
# 
# Usage:
#   BUILD=<stable|nightly|jwt> ./entrypoint.sh
#
# Environment Variables:
#   BUILD  - Determines which startup script to run. Defaults to "stable".
#              Accepted values: "stable", "nightly".
#
# Behavior:
#   - Logs timestamped messages for visibility.
#   - Normalizes BUILD to lowercase.
#   - Executes the appropriate startup script based on BUILD.
#   - Exits with error if BUILD is invalid.

# === Logging Helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') >>> UrNetwork >>> $*"
}

# Default to "stable" if BUILD is not set
BUILD="${BUILD:-stable}"
BUILD="$(echo "$BUILD" | tr '[:upper:]' '[:lower:]')"

log "Script version: v3.23.2026"
log "Starting with"
log "*** *** *** *** *** *** *** *** *** ***"
log "USER_AUTH = $USER_AUTH"
log "PASSWORD  = $PASSWORD"
log "AUTH-CODE = $AUTHCODE $JWT_TOKEN"
log "BUILD     = $BUILD"
log "PELICAN   = $PELICAN"
log "*** *** *** *** *** *** *** *** *** ***"

# === Helper to run as pelican if requested ===
run_as_user() {
  if [ "$PELICAN" = "yes" ]; then
    log "Verifying pelican user..."

    if ! grep -q "^pelican:" /etc/passwd 2>/dev/null; then
      log "Pelican user not found in passwd, creating..."
      addgroup -g 1000 pelican
      adduser -D -u 1000 -G pelican pelican
      mkdir -p /home/pelican
      chown -R root:pelican /app /root/.urnetwork
      chmod -R 775 /app /root/.urnetwork
      log "Pelican user created with proper permissions"
    else
      log "Pelican user already exists"
    fi

    log "Dropping privileges to pelican..."
    exec gosu pelican "$@"
  else
    exec "$@"
  fi
}

# Select startup script based on BUILD
case "$BUILD" in
  stable)
    run_as_user /app/start_stable.sh
    ;;
  nightly)
    run_as_user /app/start_nightly.sh
    ;;
  jwt)
    if [ "$#" -ne 1 ]; then
      log "ERROR: jwt mode requires exactly 1 argument (JWT token)"
      exit 1
    fi
    log "Entrypoint received $# arguments: $*"
    JWT_TOKEN="$1"
    run_as_user /app/start_jwt.sh "$JWT_TOKEN"
    ;;
  *)
    log "Invalid build: $BUILD"
    log "Valid options are: stable, nightly, jwt"
    exit 1
    ;;
esac