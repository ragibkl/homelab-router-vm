#!/bin/sh
set -e

echo "Starting router container..."

# Detect WAN and LAN interfaces
# WAN is the one with default route, LAN is the other
WAN_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
LAN_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo\|docker\|${WAN_IF}" | head -n1)

echo "Detected WAN interface: ${WAN_IF}"
echo "Detected LAN interface: ${LAN_IF}"

# Enable IP forwarding
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.forwarding=1

# Flush existing rules
echo "Setting up NAT rules..."
iptables -t nat -F
iptables -t nat -X

# Set up NAT (masquerading)
iptables -t nat -A POSTROUTING -o ${WAN_IF} -j MASQUERADE

# Allow forwarding from LAN to WAN
iptables -A FORWARD -i ${LAN_IF} -o ${WAN_IF} -j ACCEPT
iptables -A FORWARD -i ${WAN_IF} -o ${LAN_IF} -m state --state RELATED,ESTABLISHED -j ACCEPT

# Optional: Port forwarding examples (uncomment if needed)
# iptables -t nat -A PREROUTING -i ${WAN_IF} -p tcp --dport 8080 -j DNAT --to 192.168.100.10:8080

echo "Router configuration complete"
echo "NAT enabled: ${LAN_IF} (192.168.100.0/24) -> ${WAN_IF}"

# Keep container running and log connections
echo "Monitoring traffic..."
tail -f /dev/null
