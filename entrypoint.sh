#!/bin/bash
set -e

# -----------------------------------------------------------------------------
# Validate Required Environment Variables
# -----------------------------------------------------------------------------
if [[ -z "$USER_AUTH" || -z "$PASSWORD" ]]; then
    echo "Error: USER_AUTH or PASSWORD is not set."
    exit 1
fi

# -----------------------------------------------------------------------------
# Clear Cached Authentication Token
# -----------------------------------------------------------------------------
sleep 3
echo " "
echo " ########################## "
echo " ### Recreating JWT Cache ### "
echo " ########################## "
rm -f /root/.urnetwork/jwt
./provider auth --user_auth="${USER_AUTH}" --password="${PASSWORD}"
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
# -----------------------------------------------------------------------------
sleep 3
echo " "
echo " ################################# "
echo " ### Starting Provider Service ### "
echo " ################################# "
echo " "

sleep 3
echo " "
./provider provide &
echo " "

while true; do sleep 3600; done
