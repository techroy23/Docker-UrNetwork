#!/bin/sh

set -e  # Exit immediately if any command fails

# List of public DNS servers we want to intercept
HARD_CODED_DNS="1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4"

# Use TARGETDNS env var if provided; otherwise fall back to this IP
TARGET_DNS="${TARGETDNS:-76.76.2.3}"

# Clear out any existing NAT OUTPUT rules so we start fresh
iptables -t nat -F OUTPUT

# Loop through each DNS server in our list...
for d in $HARD_CODED_DNS; do
  # ...and add a rule to catch UDP-based DNS queries
  iptables -t nat -A OUTPUT -p udp --dport 53 -d "$d" -j DNAT --to-destination "$TARGET_DNS"
  # ...and another to catch TCP-based DNS queries
  iptables -t nat -A OUTPUT -p tcp --dport 53 -d "$d" -j DNAT --to-destination "$TARGET_DNS"
done

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
echo " "

attempt=1
max_attempts=2

while [ $attempt -le $max_attempts ]; do
    ./provider provide
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "Provider exited cleanly. Restart loop continues."
    else
        echo "Provider crashed or exited with code $exit_code."
        echo "Cleaning up JWT and sleeping to prevent auth flood..."
        rm -f /root/.urnetwork/jwt
        sleep $((15 * 60))  # Sleep for 15 minutes
    fi

    if [ $attempt -eq $max_attempts ]; then
        echo "Provider crashed twice. Exiting with code 255."
        exit 255
    fi

    ((attempt++))
done

# while true; do sleep 3600; done
