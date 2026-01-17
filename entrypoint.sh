#!/bin/sh
set -e
# Entrypoint script for selecting and starting the build of UrNetwork.
# 
# Usage:
#   BUILD=<stable|nightly> ./entrypoint.sh
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

# Simple logging function with timestamp
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

log ">>> An2Kin >>> Script version: v1.17.2026"

# Default to "stable" if BUILD is not set
BUILD="${BUILD:-stable}"
BUILD="$(echo "$BUILD" | tr '[:upper:]' '[:lower:]')"

log ">>> An2Kin >>> Starting with $BUILD build"

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
  *)
    # Handle invalid BUILD values
    log ">>> An2Kin >>> Invalid build: $BUILD"
    log ">>> An2Kin >>> Valid options are: stable, nightly"
    exit 1
    ;;
esac
