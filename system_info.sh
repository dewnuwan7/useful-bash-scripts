#!/bin/bash

#System Information

hostname=$(hostname)
kernel=$(uname -r)
uptime=$(uptime -p)
date=$(date)
users=$(users)
shell=$(basename $SHELL)

echo ""
echo "********** SYSTEM **********"
echo "Hostname: $hostname"
echo "Kernel Version: $kernel"
echo "Uptime: $uptime"
echo "Logged in Users: $users"
echo "Shell: $shell"
echo "Date: $date"

#Hardware Information

cpu=$(lscpu | grep 'Model name' | sed 's/Model name:                              //g')
ram=$(free -h | awk '/Mem/ {total=$2} /Mem/ {used=$3} /Mem/ {free=$7} END {print used, "/ ", total}')
hdd=$(df -h | grep '^/dev/' | head -n 1 | awk '{total=$2; free=$4;} END {print free,"/",total}')


echo ""
echo "********** HARDWARE **********"
echo "CPU: $cpu"
echo "RAM: $ram"
echo "STORAGE: $hdd"

#Network Information

echo ""
echo "********** NETWORK **********"

# Get interface names

for iface in $(ip -o link show | awk -F': ' '{print $2}' | awk '{print $1}'); do
    # Skip loopback
    [[ "$iface" == "lo" ]] && continue

    mac=$(ip -o link show "$iface" | awk '/link\/ether/ {print $2}')
    ipv4=$(ip -o -4 addr show "$iface" | awk '{print $4}' | paste -sd ", " -)
    ipv6=$(ip -o -6 addr show "$iface" | awk '{print $4}' | paste -sd ", " -)

    echo "Interface: $iface"
    echo "  MAC : ${mac:-N/A}"
    echo "  IPv4: ${ipv4:-N/A}"
    echo "  IPv6: ${ipv6:-N/A}"
    echo ""
done

