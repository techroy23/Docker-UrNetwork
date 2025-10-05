#!/bin/sh
 
## apk add --no-cache busybox-extras ## IF NEEDED

##-----------------------------##
##--- Configuration Section ---##
##-----------------------------##

# IP address or hostname to bind the HTTP server.
ADDR="127.0.0.1"
# TCP port number to listen on.
PORT="3001"

##-------------------------------------##
##--- Function: generate_json() -------##
##-------------------------------------##
#
# Reads network interface statistics from /proc/net/dev,
# selects interfaces matching en* or et*,
# computes per-interface and total download/upload in MB,
# and prints the result as a JSON-formatted string.
#
generate_json() {
  # Discover interfaces: en* or et*
  IFACES=$(grep -E '^[[:space:]]*(en|et)' /proc/net/dev \
           | cut -d':' -f1 | tr -d ' ')
  # Initialize running totals for RX and TX bytes
  RXTOT=0; TXTOT=0
  # Start JSON object and "interface" map
  printf '{\n  "interface": {\n'
  # Flag to manage commas between entries
  first=1
  # Loop over each interface to collect stats
  for IF in $IFACES; do
    # Extract the line for this interface, normalize spaces, then cut off the counts
    stats=$(grep "$IF" /proc/net/dev | tr -s ' ' | cut -d':' -f2)
    # RX is the first field, TX is the 9th field in /proc/net/dev after normalization
    RX=$(echo $stats | cut -d' ' -f1)
    TX=$(echo $stats | cut -d' ' -f9)
    # Add to running totals
    RXTOT=$((RXTOT+RX))
    TXTOT=$((TXTOT+TX))
    # Convert bytes to megabytes with three decimal places
    RXMB=$(awk "BEGIN{printf \"%.3f\", $RX/1024/1024}")
    TXMB=$(awk "BEGIN{printf \"%.3f\", $TX/1024/1024}")
    # Print comma before every entry except the first
    [ $first -eq 0 ] && printf ',\n'
    # Output JSON fragment for this interface
    printf '    "%s": {"DOWNLOAD":"%s MB","UPLOAD":"%s MB"}' \
           "$IF" "$RXMB" "$TXMB"
    first=0
  done
  # Close "interface" map
  printf '\n  },\n'
  # Compute totals in MB
  RXMBTOT=$(awk "BEGIN{printf \"%.3f\", $RXTOT/1024/1024}")
  TXMBTOT=$(awk "BEGIN{printf \"%.3f\", $TXTOT/1024/1024}")
  # Output total download/upload
  printf '  "total": {"DOWNLOAD":"%s MB","UPLOAD":"%s MB"}\n}\n' \
         "$RXMBTOT" "$TXMBTOT"
}

##-------------------------------------##
##--- Main Loop: HTTP Server ----------##
##-------------------------------------##
while true; do
  # Build JSON body
  BODY=$(generate_json)
  # Determine Content-Length header
  LEN=$(printf '%s' "$BODY" | wc -c)
  # Craft and send an HTTP response
  {
    printf 'HTTP/1.1 200 OK\r\n'
    printf 'Content-Type: application/json\r\n'
    printf 'Content-Length: %s\r\n' "$LEN"
    printf 'Connection: close\r\n'
    printf '\r\n'
    printf '%s' "$BODY"
  } | nc -l -s "$ADDR" -p "$PORT"
  # After serving one request, netcat exits; loop restarts
done
