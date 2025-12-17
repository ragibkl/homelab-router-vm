#!/bin/sh
set -e

curl -sfL https://get.k3s.io | K3S_URL=https://vmbr1-alpine-k3s-server-1:6443 K3S_TOKEN=<k3s-token> sh -
