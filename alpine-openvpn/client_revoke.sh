#!/bin/sh

set -e

# Check if CLIENT_NAME argument is provided
if [ -z "$1" ]; then
  echo "Error: CLIENT_NAME is required"
  echo "Usage: $0 <client-name>"
  exit 1
fi

CLIENT_NAME="$1"

# Keep the corresponding crt, key and req files.
# docker-compose run --rm openvpn ovpn_revokeclient $CLIENT_NAME

# Remove the corresponding crt, key and req files.
docker-compose run --rm openvpn ovpn_revokeclient $CLIENT_NAME remove
