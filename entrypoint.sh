#!/bin/sh

set -e

# -----------------------------------------------------------------------------
# Validate Required Environment Variables
# -----------------------------------------------------------------------------
if [ -z "$USER_AUTH" ] || [ -z "$PASSWORD" ]; then
    echo "Error: USER_AUTH or PASSWORD is not set."
    exit 1
fi

# -----------------------------------------------------------------------------
# Ensure /app Directory Exists
# -----------------------------------------------------------------------------
if [ -d "/app" ]; then
    cd /app || { echo "Failed to change directory to /app"; exit 1; }
else
    echo "Error: /app directory does not exist!"
    exit 1
fi

# -----------------------------------------------------------------------------
# Validate Provider Executable
# -----------------------------------------------------------------------------
if [ ! -x "./provider" ]; then
    echo "Making ./provider executable..."
    chmod +x ./provider || { echo "Failed to make ./provider executable"; exit 1; }
fi

# -----------------------------------------------------------------------------
# Run IP Info Script
# -----------------------------------------------------------------------------
sh /app/ipinfo.sh
sleep 3

# -----------------------------------------------------------------------------
# Main Loop
# -----------------------------------------------------------------------------
while true; do
    echo "Checking for existing JWT..."
    JWT_FILE="/root/.urnetwork/jwt"
    if [ ! -f "$JWT_FILE" ]; then
        echo "JWT not found. Authenticating..."
        ./provider auth --user_auth="${USER_AUTH}" --password="${PASSWORD}" -f
    fi

    echo "Starting provider..."
    ./provider provide &
    PROVIDER_PID=$!

    # Generate random number between 1 and 15
    if command -v shuf >/dev/null 2>&1; then
        RANDOM_MINUTES=$(shuf -i 1-15 -n 1)
    else
        RANDOM_MINUTES=$(expr $(date +%s) % 15 + 1)
    fi

    TOTAL_WAIT=$((3600 + RANDOM_MINUTES * 60))
    echo "Sleeping for $((TOTAL_WAIT / 60)) minutes before restarting provider..."
    sleep "$TOTAL_WAIT"

    echo "Killing provider process..."
    pkill -f "./provider" || echo "No matching processes found."

    echo "Deleting JWT token..."
    rm -f "$JWT_FILE"

    echo "Restarting loop..."
done
