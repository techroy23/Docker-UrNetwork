#!/bin/sh

endpoint="https://api.bringyour.com/my-ip-info"
response=$(curl -s "$endpoint")

ip=$(echo "$response" | jq -r '.info.ip')
country=$(echo "$response" | jq -r '.info.location.country.name')
vpn=$(echo "$response" | jq -r '.info.privacy.vpn')
proxy=$(echo "$response" | jq -r '.info.privacy.proxy')
tor=$(echo "$response" | jq -r '.info.privacy.tor')
relay=$(echo "$response" | jq -r '.info.privacy.relay')
hosting=$(echo "$response" | jq -r '.info.privacy.hosting')
service=$(echo "$response" | jq -r '.info.privacy.service')

printf "\n"
printf "API     : %s\n" "$endpoint"
printf "IP      : %s\n" "$ip"
printf "COUNTRY : %s\n" "$country"
printf "VPN     : %s\n" "$vpn"
printf "PROXY   : %s\n" "$proxy"
printf "TOR     : %s\n" "$tor"
printf "RELAY   : %s\n" "$relay"
printf "HOSTING : %s\n" "$hosting"
printf "SERVICE : %s\n" "$service"
printf "\n"
