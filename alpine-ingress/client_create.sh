#!/bin/sh

set -e

# Check if CLIENT_NAME argument is provided
if [ -z "$1" ]; then
  echo "Error: CLIENT_NAME is required"
  echo "Usage: $0 <client-name>"
  exit 1
fi

CLIENT_NAME="$1"

echo "Generating OpenVPN client certificate for: $CLIENT_NAME"

# with a passphrase (recommended)
# docker-compose run --rm openvpn easyrsa build-client-full $CLIENT_NAME

# without a passphrase (not recommended)
docker-compose run --rm openvpn easyrsa build-client-full $CLIENT_NAME nopass

# export
docker-compose run --rm openvpn ovpn_getclient $CLIENT_NAME > $CLIENT_NAME.ovpn

echo "Client configuration saved to: $CLIENT_NAME.ovpn"
