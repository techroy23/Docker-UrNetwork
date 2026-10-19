#!/bin/sh
# UrNetwork daily update watcher (UTC).
# -----------------------------------
# Started in the background by func_start_update_watcher. It lives in its own
# script on purpose: a shell subshell inherits the parent's argv, which made
# `ps` show a second copy of start_authcode.sh / start_userpass.sh.
#
# Usage: update_watcher.sh <HH:MM> <provider-name> <update-flag-file>

. /app/provider_common.sh

UPDATE_TIME="${1:-$UPDATE_TIME}"
PROVIDER_NAME="${2:-$PROVIDER_NAME}"
UPDATE_FLAG="${3:-$UPDATE_FLAG}"

last_day=""
while :; do
    now="$(date -u +%H:%M)"
    day="$(date -u +%Y-%m-%d)"
    if [ "$now" = "$UPDATE_TIME" ] && [ "$last_day" != "$day" ]; then
        last_day="$day"
        log "[INFO] Watcher: update time $UPDATE_TIME UTC reached"
        : > "$UPDATE_FLAG"
        if [ -n "$PROVIDER_NAME" ]; then
            pkill -f "$APP_DIR/$PROVIDER_NAME" 2>/dev/null || log "[INFO] Watcher: no provider process to stop"
        fi
        sleep 90
    fi
    sleep 20
done
