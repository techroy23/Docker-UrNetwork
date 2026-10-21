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
#   - Runs as the unprivileged `urnetwork` user (the image's default USER).
#   - If started as root, drops to `urnetwork` through gosu before startup.
#   - Executes the matching startup script.
#   - Exits with an error if AUTH is invalid.

APP_USER="urnetwork"

# === Logging Helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') >>> UrNetwork >>> $*"
}

log "Script version: v10.21.2026"

# The provider resolves its state directory from HOME.
export HOME=/home/urnetwork

# Provider custody is tied to the runtime UID. Only the image default (1000)
# and root (which drops through gosu) are supported.
runtime_uid="$(id -u "$APP_USER" 2>/dev/null || echo '')"
if [ "$(id -u)" != "0" ] && [ -n "$runtime_uid" ] && [ "$(id -u)" != "$runtime_uid" ]; then
  log "[ERROR] Unsupported runtime uid $(id -u); the provider runs as $APP_USER (uid $runtime_uid)"
  log "[ERROR] Start the image with its default user, or with --user 0 to drop via gosu"
  exit 1
fi

# Root is not the normal path: the image runs as `urnetwork`. Keep gosu for
# the case where the container is explicitly started with --user 0.
run_as_user() {
  if [ "$(id -u)" = "0" ]; then
    log "[INFO] Started as root; dropping privileges to $APP_USER"
    exec gosu "$APP_USER:$APP_USER" "$@"
  fi
  exec "$@"
}

# Default to "userpass" if AUTH is not set
AUTH="${AUTH:-userpass}"
AUTH="$(echo "$AUTH" | tr '[:upper:]' '[:lower:]')"

# === Auth mode dispatch ===
run_userpass() {
  run_as_user /app/start_userpass.sh
}

run_authcode() {
  AUTH_CODE="${1:-$AUTHCODE}"
  if [ -z "$AUTH_CODE" ]; then
    log "[ERROR] AUTH=authcode requires an auth code"
    log "[ERROR] Pass it as the first argument or set -e AUTHCODE"
    exit 1
  fi
  log "Auth code provided"
  run_as_user /app/start_authcode.sh "$AUTH_CODE"
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
