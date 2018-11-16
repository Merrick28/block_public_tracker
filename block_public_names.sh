#!/bin/bash
##########################################
# Block public trackers with names
# using /etc/hosts
##########################################
# Please tun as root or use sudo
##########################################
if [[ "$EUID" -ne 0 ]];
  then echo "Please run as root or use sudo"  
  exit 1
fi

##########################################
# Clean current entries
cp /etc/hosts /etc/hosts.before_public_tracker
sed '/### PUBLIC TRACKER START ###/,/### PUBLIC TRACKER END ###/{//!d}' /etc/hosts > /tmp/hosts
mv /tmp/hosts /etc/hosts
# test if the /etc/hosts file has used this script before
if grep -q SomeString "$File"i
then
  :
else
  echo "### PUBLIC TRACKER START" >> /etc/hosts
  echo "### PUBLIC TRACKER END" >> /etc/hosts
fi
# Grep line number
line_number=$(grep -n "### PUBLIC TRACKER START ###" /etc/hosts|awk -F':' '{print $1}')
line_number=$(($line_number + 1))
# get public tracker list
curl https://raw.githubusercontent.com/ngosang/trackerslist/master/blacklist.txt > /tmp/public_trackers
# inert into /etc/hosts
for line in $(cat /tmp/public_trackers | awk -F'/' '{print $3}'|awk -F':' '{print $1}'|sort|uniq)
do
  sed -i "${line_number}i 127.0.0.1 ${line}" /etc/hosts
done
