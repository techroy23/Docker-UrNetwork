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
# Proxy Configuration (if applicable)
# -----------------------------------------------------------------------------
if [ -n "$proxy" ]; then
    echo "##### Configuring ProxyChains #####"
    protocol=$(echo "$proxy" | awk -F'://' '{print $1}')
    auth=$(echo "$proxy" | awk -F'@' '{print $1}' | awk -F'://' '{print $2}')
    username=$(echo "$auth" | awk -F':' '{print $1}')
    password=$(echo "$auth" | awk -F':' '{print $2}')
    address=$(echo "$proxy" | awk -F'@' '{print $2}' | awk -F':' '{print $1}')
    port=$(echo "$proxy" | awk -F':' '{print $NF}')
    if [[ -z "$protocol" || -z "$username" || -z "$password" || -z "$address" || -z "$port" ]]; then
        echo "Error: Unable to parse proxy details correctly!"
        exit 1
    fi
    cat <<EOF > /etc/proxychains.conf
dynamic_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
$protocol $address $port $username $password
EOF

    echo "Using ProxyChains..."
    sleep 3
    proxychains4 ./provider auth --user_auth="${USER_AUTH}" --password="${PASSWORD}"
    sleep 3
    proxychains4 ./provider provide &
else
    echo "No proxy set. Running app directly..."
    sleep 3
    ./provider auth --user_auth="${USER_AUTH}" --password="${PASSWORD}"
    sleep 3
    proxychains4 ./provider provide &
fi

# -----------------------------------------------------------------------------
# Keep Script Running Indefinitely to Prevent Premature Container Exit
# -----------------------------------------------------------------------------
sleep 3
echo " "
echo "##### Running Indefinitely #####"
echo " "

while true; do sleep 3600; done
