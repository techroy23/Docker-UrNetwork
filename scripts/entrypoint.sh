#!/bin/sh
set -e
# Entrypoint bootstrapper for the UrNetwork provider container.
#
# Usage:
#   AUTH=<userpass|authcode> ./entrypoint.sh [<AUTH-CODE>]
#
# Environment Variables:
#   AUTH       - Authentication mode. Defaults to "userpass".
#                "userpass" : log in with USER_AUTH + PASSWORD (long running provider).
#                "authcode" : exchange an auth code for a JWT (AUTHCODE or $1).
#   AUTHCODE   - Auth code for AUTH=authcode (used when no argument is given).
#
# Behavior:
#   - Logs timestamped messages for visibility.
#   - Normalizes AUTH to lowercase.
#   - Executes the matching startup script.
#   - Exits with an error if AUTH is invalid.

# === Logging Helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') >>> UrNetwork >>> $*"
}

log "Script version: v10.17.2026"

# Default to "userpass" if AUTH is not set
AUTH="${AUTH:-userpass}"
AUTH="$(echo "$AUTH" | tr '[:upper:]' '[:lower:]')"

# === Auth mode dispatch ===
run_userpass() {
  exec /app/start_userpass.sh
}

run_authcode() {
  AUTH_CODE="${1:-$AUTHCODE}"
  if [ -z "$AUTH_CODE" ]; then
    log "[ERROR] AUTH=authcode requires an auth code"
    log "[ERROR] Pass it as the first argument or set -e AUTHCODE"
    exit 1
  fi
  log "Auth code provided"
  exec /app/start_authcode.sh "$AUTH_CODE"
}

case "$AUTH" in
  userpass)
    run_userpass
    ;;
  authcode)
    run_authcode "$@"
    ;;
  *)
    log "[ERROR] Invalid auth mode: $AUTH"
    log "[ERROR] Valid options are: userpass, authcode"
    exit 1
    ;;
esac
