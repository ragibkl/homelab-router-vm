#!/bin/sh
set -e

echo "Starting router container..."

# Detect WAN and LAN interfaces
# WAN is the one with default route, LAN is the other
WAN_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
LAN_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo\|docker\|${WAN_IF}" | head -n1)

echo "Detected WAN interface: ${WAN_IF}"
echo "Detected LAN interface: ${LAN_IF}"

# Get WAN network (e.g., 192.168.1.0/24)
WAN_NETWORK=$(ip -o -f inet addr show ${WAN_IF} | awk '{print $4}' | sed 's/\.[0-9]*\//\.0\//')

echo "Detected WAN network: ${WAN_NETWORK}"

# Flush existing rules
echo "Flushing iptables rules..."
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X

# Default policies
iptables -P FORWARD DROP
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT

# Allow established/related connections
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow LAN to WAN (internet access)
echo "Allowing LAN → WAN traffic..."
iptables -A FORWARD -i ${LAN_IF} -o ${WAN_IF} -j ACCEPT

# Block LAN to home network
echo "Blocking LAN → home network (${WAN_NETWORK})..."
iptables -A FORWARD -i ${LAN_IF} -d ${WAN_NETWORK} -j DROP

# NAT for LAN to internet
echo "Setting up NAT..."
iptables -t nat -A POSTROUTING -o ${WAN_IF} -j MASQUERADE

# Port forward: OpenVPN (WAN:1194 → ingress:1194)
echo "Setting up OpenVPN port forward..."
INGRESS_IP="192.168.100.5"
OPENVPN_PORT="1194"

iptables -t nat -A PREROUTING -i ${WAN_IF} -p udp --dport ${OPENVPN_PORT} -j DNAT --to-destination ${INGRESS_IP}:${OPENVPN_PORT}
iptables -A FORWARD -i ${WAN_IF} -o ${LAN_IF} -p udp -d ${INGRESS_IP} --dport ${OPENVPN_PORT} -j ACCEPT

echo "Router configuration complete"
echo "NAT enabled: ${LAN_IF} -> ${WAN_IF}"
echo "Home network blocked: ${LAN_IF} -X-> ${WAN_NETWORK}"
echo "OpenVPN forwarded: ${WAN_IF}:${OPENVPN_PORT} -> ${INGRESS_IP}:${OPENVPN_PORT}"

# Show final rules
echo ""
echo "=== FORWARD Rules ==="
iptables -L FORWARD -v -n --line-numbers
echo ""
echo "=== NAT PREROUTING Rules ==="
iptables -t nat -L PREROUTING -v -n --line-numbers
echo ""
echo "=== NAT POSTROUTING Rules ==="
iptables -t nat -L POSTROUTING -v -n --line-numbers

# Keep container running
echo ""
echo "Monitoring traffic..."
tail -f /dev/null
