#!/bin/bash

echo "Downloading metadata... setting up PRIVATE_IP_RANGES variable"
eval  $(curl -H "Metadata: true" -s http://169.254.169.254/metadata/instance?api-version=2025-04-07 | jq -r ".compute.userData" | base64 --decode)
IFS=',' 
read -a arr <<< $PRIVATE_IP_RANGES

echo "Remove default route..."
ip route del default

echo "Searching internet gateway..."
IP=$(route -n |grep 'U[ \t].*eth1' | awk '{print $1}')
LAST_OCTET="${IP##*.}"
PREFIX="${IP%.*}"
DEF_GW="${PREFIX}.$((LAST_OCTET + 1))"

echo "Setting up internet routing via $DEF_GW..."
ip route add 0.0.0.0/0 via $DEF_GW

echo "Updating system..."
apt update
apt upgrade -y
apt install iptables-persistent traceroute net-tools mc -y

echo "Setting up internal network routing..."

IP=$(route -n |grep 'U[ \t].*eth0' | awk '{print $1}')
LAST_OCTET="${IP##*.}"
PREFIX="${IP%.*}"
INT_GW="${PREFIX}.$((LAST_OCTET + 1))"

for i in "${arr[@]}"; do
 echo "Adding range: $i"
 ip route add $i via $INT_GW
done


echo "Setting up packet forwarding..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

iptables -F 
iptables -X FORWARD
iptables -X POSTROUTING
iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
netfilter-persistent save
