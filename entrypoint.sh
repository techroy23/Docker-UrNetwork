#!/bin/sh

set -e

# -----------------------------------------------------------------------------
# Validate Required Environment Variables
# -----------------------------------------------------------------------------
if [[ -z "$USER_AUTH" || -z "$PASSWORD" ]]; then
    echo "Error: USER_AUTH or PASSWORD is not set."
    exit 1
fi

# -----------------------------------------------------------------------------
# Check for Cached Authentication Token
# -----------------------------------------------------------------------------
sleep 3
echo " "
JWT_FILE="/root/.urnetwork/jwt"
if [ -f "$JWT_FILE" ]; then
    echo " ################################ "
    echo " ### Found existing JWT Token ### "
    echo " ################################ "
else
    echo " ############################ "
    echo " ### Recreating JWT Cache ### "
    echo " ############################ "
    ./provider auth --user_auth="${USER_AUTH}" --password="${PASSWORD}" -f
fi
echo " "

# -----------------------------------------------------------------------------
# Ensure /app Directory Exists Before Changing to It
# -----------------------------------------------------------------------------
if [[ -d "/app" ]]; then
    cd /app || { echo "Failed to change directory to /app"; exit 1; }
else
    echo "Error: /app directory does not exist!"
    exit 1
fi

# -----------------------------------------------------------------------------
# Validate Provider Executable Before Running
# -----------------------------------------------------------------------------
if ! [[ -x "./provider" ]]; then
    echo "Error: ./provider is missing or not executable!"
    chmod +x ./provider || { echo "Failed to make ./provider executable"; exit 1; }
fi

# -----------------------------------------------------------------------------
# Keep Script Running Indefinitely to Prevent Premature Container Exit
# With Crash Handling and Throttling
# -----------------------------------------------------------------------------
sh /app/ipinfo.sh

sleep 3
echo " "
echo " ################################# "
echo " ### Starting Provider Service ### "
echo " ################################# "
echo " "

sleep 3

attempt=1
max_attempts=2

while [ $attempt -le $max_attempts ]; do
    ./provider provide
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo " "
        echo " ######################################################## "
        echo " ### Provider exited cleanly. Restart loop continues. ### "
        echo " ######################################################## "
        echo " "
    else
        echo " "
        echo "Provider crashed or exited with code $exit_code."
        echo " "
        echo " ############################################################# "
        echo " ### Cleaning up JWT and sleeping to prevent auth flood... ### "
        echo " ############################################################# "
        echo " "
        rm -f /root/.urnetwork/jwt
        sleep $((15 * 60))  # Sleep for 15 minutes
    fi

    if [ $attempt -eq $max_attempts ]; then
        echo " "
        echo " ###################################################### " 
        echo " ### Provider crashed twice. Exiting with code 255. ### "
        echo " ###################################################### " 
        echo " "
        exit 255
    fi

    ((attempt++))
done

# while true; do sleep 3600; done