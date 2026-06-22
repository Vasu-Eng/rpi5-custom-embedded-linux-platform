#!/bin/ash

# Reserved for future services

echo "Bringing up Ethernet..."
ifconfig eth0 up

echo "Requesting DHCP lease..."
udhcpc -i eth0

echo "Network configuration:"
ifconfig eth0


exit 0
