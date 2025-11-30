#!/bin/sh

set -e

# Docs: https://github.com/kylemanna/docker-openvpn/blob/master/docs/docker-compose.md

docker-compose run --rm openvpn ovpn_genconfig -u udp://vmbr1.ingress.ragib.my
docker-compose run --rm openvpn ovpn_initpki

chown -R $(whoami): ./openvpn-data
