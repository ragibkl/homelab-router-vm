#!/bin/sh
set -e

curl -sfL https://get.k3s.io | sh -s - server \
    --disable traefik \
    --node-taint CriticalAddonsOnly=true:NoExecute

echo K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
