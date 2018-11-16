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
NOWRULES=$(iptables --line-number -nL INPUT | grep block_public_tracker | awk '{print $1}' | tac) 
for rul in $NOWRULES
do 
  iptables -D INPUT $rul; sleep 0.1
done
##########################################
# get public tracker list
curl https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt > ${ip_list}
# insert into iptables
for line in $(cat ${ip_list} | awk -F'/' '{print $3}'|awk -F':' '{print $1}'|sort|uniq)
do
   iptables -I INPUT -s ${line} -j DROP -m comment --comment "Blocked by block_public_tracker"
done
