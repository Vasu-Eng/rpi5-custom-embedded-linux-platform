#!/bin/ash

# Reserved for future services

echo "Bringing up Ethernet..."
ifconfig eth0 up

echo "Requesting DHCP lease..."
if ! udhcpc -i eth0 -n -t 5
then
    echo "DHCP failed, assigning fallback IP..."
    ifconfig eth0 192.168.1.200 netmask 255.255.255.0
     echo "used static ip 192.168.1.200/24..."

fi

echo "Starting Dropbear SSH..."
mkdir -p /var/run
dropbear  -E

echo "Network configuration:"
ifconfig eth0

exit 0
