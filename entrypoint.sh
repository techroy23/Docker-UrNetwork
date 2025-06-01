#!/bin/bash
set -e

sleep 3
echo "##### Fetching Latest Release Info #####"
RELEASE_URL="https://api.github.com/repos/urnetwork/build/releases/latest"
echo "Checking: $RELEASE_URL"
TAR_URL=$(curl -s "$RELEASE_URL" | grep '"browser_download_url":' | grep '.tar.gz"' | cut -d '"' -f 4)
echo " "

sleep 3
echo "##### Downloading Provider Binary #####"
echo "Downloading: $TAR_URL"
wget -q "$TAR_URL" -O latest.tar.gz
echo " "

sleep 3
echo "##### Extracting Provider Binary #####"
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    TARGET_ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    TARGET_ARCH="arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

echo "Detected architecture: $TARGET_ARCH"
tar -xzf latest.tar.gz --strip-components=2 -C /app linux/$TARGET_ARCH/provider
chmod +x /app/provider

rm latest.tar.gz
echo " "

sleep 3
echo "##### Clearing JWT Cache #####"
rm -f /root/.urnetwork/jwt
echo " "

sleep 5
cd /app
echo "##### Authenticating Provider #####"
./provider auth --user_auth="${USER_AUTH}" --password="${PASSWORD}"
echo " "

sleep 5
echo "##### Starting Provider #####"
./provider provide &
echo " "

sleep 30
echo "##### Checking Network Activity #####"
netstat -p
echo " "

sleep 10
echo "##### Running Indefinitely #####"
tail -f /dev/null
echo " "
