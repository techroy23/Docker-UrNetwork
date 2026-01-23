#!/bin/sh

# === Logging Helper ===
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') >>> UrNetwork >>> $*"
}

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

log "### ### ###"
log "API     : $endpoint"
log "IP      : $ip"
log "COUNTRY : $country"
log "VPN     : $vpn"
log "PROXY   : $proxy"
log "TOR     : $tor"
log "RELAY   : $relay"
log "HOSTING : $hosting"
log "SERVICE : $service"
log "### ### ###"
