# block_public_tracker

Allows to block public trackers on your server. The list of public names and IP adresses comes from https://github.com/ngosang/trackerslist

# Usage

Every script must be launched as root, or using sudo.
Every script cleans itw own previous actions before creating new ones.

## block_public_ips.sh

Creates iptables rules to block IP. Each rule has a comment "Blocked by block_public_tracker"

## block_public_names.sh

Creates an entry in /etc/hosts for each public tracker, pointing to 0.0.0.0 to avoid making useless connection

## block_ipset.sh

Uses ipset to block a large aumount of IP's.
Modify all vars before launching.

## Use a crontab 

As root, you can create a file in /etc/cron.daily to update daily the black list :

```
# /etc/cron.daily/block_public_tracker
<full_path>/block_public_ips.sh
<full_path>/block_public_names.sh
<full_path>/block_ipset.sh
```

Then chmod 755 /etc/cron.daily/block_public_tracker

