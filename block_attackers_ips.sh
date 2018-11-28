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
# Delete the current rules
NOWRULES=$(iptables --line-number -nL INPUT | grep block_public_attacker | awk '{print $1}' | tac)
for rul in $NOWRULES
do 
  iptables -D INPUT $rul; sleep 0.1
done
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
