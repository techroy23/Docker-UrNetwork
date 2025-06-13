#!/bin/bash
set -e  # Exit script immediately if any command fails

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
echo "##### Clearing JWT Cache #####"
rm -f /root/.urnetwork/jwt
echo " "

# -----------------------------------------------------------------------------
# Ensure /app Directory Exists Before Changing to It
# -----------------------------------------------------------------------------
if [[ ! -d "/app" ]]; then
    echo "Error: /app directory does not exist!"
    exit 1
fi

cd /app || { echo "Failed to change directory to /app"; exit 1; }

# -----------------------------------------------------------------------------
# Validate Provider Executable Before Running
# -----------------------------------------------------------------------------
if [[ ! -x "./provider" ]]; then
    echo "Error: ./provider is missing or not executable!"
    exit 1
fi

# -----------------------------------------------------------------------------
# Keep Script Running Indefinitely to Prevent Premature Container Exit
# -----------------------------------------------------------------------------
sleep 3
echo " "
echo "##### Running Indefinitely #####"
echo " "
echo "No proxy set. Running app directly..."
sleep 3
echo " "
./provider auth --user_auth="${USER_AUTH}" --password="${PASSWORD}"
sleep 3
echo " "
./provider provide &
echo " "

while true; do sleep 3600; done
