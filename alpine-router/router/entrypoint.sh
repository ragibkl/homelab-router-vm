#!/bin/sh
set -e

echo "Starting router container..."

# Detect WAN and LAN interfaces
WAN_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
LAN_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo\|docker\|${WAN_IF}" | head -n1)

echo "Detected WAN interface: ${WAN_IF}"
echo "Detected LAN interface: ${LAN_IF}"

# Get WAN network
WAN_NETWORK=$(ip -o -f inet addr show ${WAN_IF} | awk '{print $4}' | sed 's/\.[0-9]*\//\.0\//')
echo "Detected WAN network: ${WAN_NETWORK}"

# Get LAN network
LAN_NETWORK=$(ip -o -f inet addr show ${LAN_IF} | awk '{print $4}' | sed 's/\.[0-9]*\//\.0\//')
echo "Detected LAN network: ${LAN_NETWORK}"

# Flush existing rules
echo "Flushing iptables rules..."
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X

# Default policies
iptables -P FORWARD DROP
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established/related connections
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow SSH from both WAN and LAN
iptables -A INPUT -i ${WAN_IF} -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -i ${LAN_IF} -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS from both WAN and LAN
iptables -A INPUT -i ${WAN_IF} -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -i ${LAN_IF} -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -i ${WAN_IF} -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -i ${LAN_IF} -p tcp --dport 443 -j ACCEPT

# Allow ICMP (ping) from both WAN and LAN for troubleshooting
iptables -A INPUT -i ${WAN_IF} -p icmp -j ACCEPT
iptables -A INPUT -i ${LAN_IF} -p icmp -j ACCEPT

# Allow DHCP on LAN interface
echo "Allowing DHCP on LAN interface..."
iptables -A INPUT -i ${LAN_IF} -p udp --dport 67 -j ACCEPT  # DHCP server
iptables -A INPUT -i ${LAN_IF} -p udp --dport 68 -j ACCEPT  # DHCP client (for relay)

# Allow DNS on LAN interface (if dnsmasq provides DNS too)
iptables -A INPUT -i ${LAN_IF} -p udp --dport 53 -j ACCEPT
iptables -A INPUT -i ${LAN_IF} -p tcp --dport 53 -j ACCEPT

# Block LAN → WAN network (home LAN)
echo "Blocking LAN → WAN network (${WAN_NETWORK})..."
iptables -A FORWARD -i ${LAN_IF} -d ${WAN_NETWORK} -j LOG --log-prefix "BLOCKED-HOME: " --log-level 4
iptables -A FORWARD -i ${LAN_IF} -d ${WAN_NETWORK} -j DROP

# Block LAN → all RFC1918 private ranges
echo "Blocking LAN → all RFC1918 private ranges..."
iptables -A FORWARD -i ${LAN_IF} -d 10.0.0.0/8 -j DROP
iptables -A FORWARD -i ${LAN_IF} -d 172.16.0.0/12 -j DROP
iptables -A FORWARD -i ${LAN_IF} -d 192.168.0.0/16 -j DROP

# Allow LAN → WAN (internet) - comes AFTER blocks
echo "Allowing LAN → Internet traffic..."
iptables -A FORWARD -i ${LAN_IF} -o ${WAN_IF} -j ACCEPT

# NAT for LAN → internet
echo "Setting up NAT..."
iptables -t nat -A POSTROUTING -s ${LAN_NETWORK} -o ${WAN_IF} -j MASQUERADE

# ====== Generic Port Forwarding ======
echo "Setting up port forwards..."

# Format: external_port:protocol:internal_ip:internal_port
# Example: PORT_FORWARDS="1194:udp:10.15.1.100:1194,80:tcp:10.15.1.101:8080"
if [ -n "$PORT_FORWARDS" ]; then
    # Split by comma
    IFS=',' read -ra FORWARDS <<< "$PORT_FORWARDS"
    
    for forward in "${FORWARDS[@]}"; do
        # Split by colon: external_port:protocol:internal_ip:internal_port
        IFS=':' read -r external_port protocol internal_ip internal_port <<< "$forward"
        
        # Validate protocol
        if [ "$protocol" != "tcp" ] && [ "$protocol" != "udp" ]; then
            echo "WARNING: Invalid protocol '$protocol' in forward '$forward', skipping"
            continue
        fi
        
        # Validate we have all required fields
        if [ -z "$external_port" ] || [ -z "$protocol" ] || [ -z "$internal_ip" ] || [ -z "$internal_port" ]; then
            echo "WARNING: Invalid format '$forward', skipping"
            continue
        fi
        
        # Add DNAT rule
        iptables -t nat -A PREROUTING -i ${WAN_IF} -p $protocol --dport $external_port \
            -j DNAT --to-destination ${internal_ip}:${internal_port}
        
        # Allow forwarded traffic
        iptables -A FORWARD -i ${WAN_IF} -p $protocol -d $internal_ip --dport $internal_port -j ACCEPT
        
        echo "  ✓ WAN:$external_port/$protocol -> ${internal_ip}:${internal_port}"
    done
else
    echo "  No port forwards configured"
fi

echo ""
# ====== End Port Forwarding ======

# Block WAN → LAN (no inbound connections)
iptables -A FORWARD -i ${WAN_IF} -o ${LAN_IF} -j DROP

echo ""
echo "=== Router Configuration Complete ==="
echo "WAN Interface:     ${WAN_IF}"
echo "LAN Interface:     ${LAN_IF}"
echo "WAN Network:       ${WAN_NETWORK}"
echo "LAN Network:       ${LAN_NETWORK}"
echo "NAT:               ${LAN_IF} -> ${WAN_IF}"
echo "Home blocked:      ${LAN_IF} -X-> ${WAN_NETWORK}"
echo "All private:       BLOCKED"
echo "DHCP:              ENABLED on ${LAN_IF}"
echo "SSH:               ENABLED on both interfaces"
echo "HTTP/HTTPS:        ENABLED on both interfaces"
echo ""

# Show final rules
echo "=== FORWARD Rules ==="
iptables -L FORWARD -v -n --line-numbers
echo ""
echo "=== NAT POSTROUTING Rules ==="
iptables -t nat -L POSTROUTING -v -n --line-numbers
echo ""
echo "=== INPUT Rules ==="
iptables -L INPUT -v -n --line-numbers
echo ""

# Keep container running
echo "Router is running. To view blocked traffic, run:"
echo "  docker exec <container> dmesg | grep BLOCKED-HOME"
echo ""
tail -f /dev/null
