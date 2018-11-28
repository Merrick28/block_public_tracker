#!/bin/bash
##########################################
# Block public trackers with Ips
# using iptables
##########################################
# Please run as root or use sudo
##########################################
if [[ "$EUID" -ne 0 ]];
  then echo "Please run as root or use sudo"  
  exit 1
fi

ip_list=$(tempfile)

##########################################
# get public tracker list
# adapt the timer in seconds
# 3600 => every hour
# 86400 => every day
curl http://api.blocklist.de/getlast.php?time=3600 > ${ip_list}
# insert into iptables
for line in $(cat ${ip_list})
do
   iptables -I INPUT -s ${line} -j DROP -m comment --comment "Blocked by block_public_attacker"
done
