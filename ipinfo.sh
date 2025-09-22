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

printf ">>> An2Kin >>> ### ### ### \n"
printf ">>> An2Kin >>> API     : %s\n" "$endpoint"
printf ">>> An2Kin >>> IP      : %s\n" "$ip"
printf ">>> An2Kin >>> COUNTRY : %s\n" "$country"
printf ">>> An2Kin >>> VPN     : %s\n" "$vpn"
printf ">>> An2Kin >>> PROXY   : %s\n" "$proxy"
printf ">>> An2Kin >>> TOR     : %s\n" "$tor"
printf ">>> An2Kin >>> RELAY   : %s\n" "$relay"
printf ">>> An2Kin >>> HOSTING : %s\n" "$hosting"
printf ">>> An2Kin >>> SERVICE : %s\n" "$service"
printf ">>> An2Kin >>> ### ### ### \n"
