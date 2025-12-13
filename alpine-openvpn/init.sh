#!/bin/sh

set -e

# Check if SERVER_NAME argument is provided
if [ -z "$1" ]; then
  echo "Error: SERVER_NAME is required"
  echo "Usage: $0 <server-name>"
  exit 1
fi

SERVER_NAME="$1"

# Docs: https://github.com/kylemanna/docker-openvpn/blob/master/docs/docker-compose.md

docker-compose run --rm openvpn ovpn_genconfig -u udp://${SERVER_NAME}
docker-compose run --rm openvpn ovpn_initpki

chown -R $(whoami): ./openvpn-data
