#!/bin/sh

echo "Remove default route..."
ip route del default

echo "Searching internet gateway..."
IP=$(route -n |grep 'U[ \t].*eth1' | awk '{print $1}')
IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
DEF_GW=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)

echo "Setting up internet routing via $DEF_GW..."
ip route add 0.0.0.0/0 via $DEF_GW

echo "Updating system..."
apt update
apt upgrade -y
apt install iptables-persistent traceroute net-tools mc -y

echo "Setting up internal network routing..."
IP=$(route -n | grep 'U[ \t].*eth0' | awk '{print $1}')
IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
INT_GW=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
echo "Internal gateway ip addres: $INT_GW"

for i in "${@}"; do
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
