# block_public_tracker

Allows to block public trackers on your server. The list of public names and IP adresses comes from https://github.com/ngosang/trackerslist

# Usage

Every script must be launched as root, or using sudo.
Every script cleans itw own previous actions before creating new ones.

## block_public_ips.sh

Creates iptables rules to block IP. Each rule has a comment "Blocked by block_public_tracker"

## block_public_names.sh

Creates an entry in /etc/hosts for each public tracker, pointing to 127.0.0.1 (localhost)
