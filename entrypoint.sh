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
    echo " "
    echo " ################################# "
    echo " ### Checking for existing JWT ### "
    echo " ################################# "
    echo " "
    JWT_FILE="/root/.urnetwork/jwt"
    if [ ! -f "$JWT_FILE" ]; then
        echo " "
        echo " ############################ "
        echo " ### Recreating JWT Cache ### "
        echo " ############################ "
        echo " "
        ./provider auth --user_auth="${USER_AUTH}" --password="${PASSWORD}" -f
    fi

    echo " "
    echo " ################################# "
    echo " ### Starting Provider Service ### "
    echo " ################################# "
    echo " "
    ./provider provide &
    PROVIDER_PID=$!

    if command -v shuf >/dev/null 2>&1; then
        RANDOM_MINUTES=$(shuf -i 1-15 -n 1)
    else
        RANDOM_MINUTES=$(expr $(date +%s) % 15 + 1)
    fi

    TOTAL_WAIT=$((14400 + RANDOM_MINUTES * 60))
    echo " "
    echo " ############################################################# "
    echo " ### Sleeping for $((TOTAL_WAIT / 60)) minutes before restarting provider... ### "
    echo " ############################################################# "
    echo " "
    sleep "$TOTAL_WAIT"

    echo " "
    echo " ################################### "
    echo " ### Killing provider process... ### "
    echo " ################################### "
    echo " "
    pkill -f "./provider" || echo "No matching processes found."

    echo " "
    echo " ############################# "
    echo " ### Deleting JWT token... ### "
    echo " ############################# "
    echo " "
    rm -f "$JWT_FILE"

    echo " "
    echo " ########################## "
    echo " ### Restarting loop... ### "
    echo " ########################## "
    echo " "

done
