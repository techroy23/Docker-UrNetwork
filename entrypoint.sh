#!/bin/bash
set -e

if [[ -z "$USER_AUTH" || -z "$PASSWORD" ]]; then
    echo "Error: USER_AUTH or PASSWORD is not set."
    exit 1
fi

sleep 2
echo "##### Clearing JWT Cache #####"
rm -f /root/.urnetwork/jwt
echo " "

sleep 2
cd /app
echo "##### Authenticating Provider #####"
./provider auth --user_auth="${USER_AUTH}" --password="${PASSWORD}"
echo " "

sleep 2
echo "##### Starting Provider #####"
./provider provide &

sleep 2
echo " "
echo "##### Running Indefinitely #####"
echo " "

tail -f /dev/null
echo " "
