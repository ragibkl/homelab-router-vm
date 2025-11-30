#!/bin/sh

set -e

export CLIENTNAME="ragibkl"

# with a passphrase (recommended)
# docker-compose run --rm openvpn easyrsa build-client-full $CLIENTNAME

# without a passphrase (not recommended)
docker-compose run --rm openvpn easyrsa build-client-full $CLIENTNAME nopass

# export
docker-compose run --rm openvpn ovpn_getclient $CLIENTNAME > $CLIENTNAME.ovpn
