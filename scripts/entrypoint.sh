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

log "Script version: v3.15.2026"
log "Starting with"
log "USER_AUTH = $USER_AUTH"
log "PASSWORD  = $PASSWORD"
log "BUILD     = $BUILD"


# Select startup script based on BUILD
case "$BUILD" in
  stable)
    # Run the stable startup script
    exec /app/start_stable.sh
    ;;
  nightly)
    # Run the nightly startup script
    exec /app/start_nightly.sh
    ;;
  jwt)
    # Run the jwt startup script
    if [ "$#" -ne 1 ]; then
      log "ERROR: jwt mode requires exactly 1 argument (JWT token)"
      exit 1
    fi
    log "Entrypoint received $# arguments: $*"
    JWT_TOKEN="$1"
    exec /app/start_jwt.sh "$JWT_TOKEN"
    ;;
  *)
    # Handle invalid BUILD values
    log "Invalid build: $BUILD"
    log "Valid options are: stable, nightly, jwt"
    exit 1
    ;;
esac
