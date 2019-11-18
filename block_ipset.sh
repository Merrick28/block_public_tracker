#!/bin/bash
##############################################################
# INSPIRED FROM
# https://www.lexo.ch/blog/2019/09/blocklist-de-iptables-ipset-update-script-how-to-automatically-update-your-firewall-with-the-ip-set-from-blocklist-de/
##############################################################


# Lists
declare -A LIST_TO_DOWNLOAD
LIST_TO_DOWNLOAD['blocklist.de']="http://lists.blocklist.de/lists/all.txt"
LIST_TO_DOWNLOAD['public-trackers']="https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt"
# Add other lists if necessary
# LIST_TO_DOWNLOAD['iBlock-Government']="http://list.iblocklist.com/?list=lakuncfhfhgiqghqxjzi&fileformat=cidr&archiveformat=&username=xxxxxxxx&pin=xxxxxxxx"
# If you use iBlock, please select CIDR format, without compression

# Paths
IPTABLES_PATH="/sbin/iptables"
IPSET_PATH="/sbin/ipset"
SORT_PATH="/usr/bin/sort"
MAIL_PATH="/usr/bin/mail"
GREP_PATH="/bin/grep"

#Log file
LOG_FILE="/var/log/block_ipset.log"

#Action
ACTION="REJECT" # Can be DROP or REJECT

# DEBUG, false by default
DEBUG=false # can be true or false

# E-Mail variables
SEND_MAIL=false # true = send mail, false = no mail ...
MAIL_SENDER="seed" #this defines a system-user without a shell or password.
MAIL_SUBJECT="ERROR - IP blocklist script failed to download the IP set"
MAIL_RECIPIENTS="me@mydomain.com" #send mail to multiple receipients by overgiving a space-seperated address list

###################################################################################################
# DO NOT TOUCH FROM HERE

if [[ "$EUID" -ne 0 ]];
  then echo "Please run as root or use sudo"
  exit 1
fi

if [ ! -f $IPTABLES_PATH ]; then  echo "Cannot find [ iptables ]. Is it installed? Exiting"; exit 1; fi;
if [ ! -f $IPSET_PATH ]; then echo "Cannot find [ ipset ]. Is it installed? Exiting"; exit 1; fi;
if [ ! -f $SORT_PATH ]; then echo "Cannot find [ sort ]. Is it installed? Exiting"; exit 1; fi;
if [ "$SEND_MAIL" = true ]
    then
    if [ ! -f $MAIL_PATH ]; then echo "Cannot find [ mail ]. Is it installed? Try apt install mailutils. Exiting"; exit 1; fi;
fi
if [ ! -f $GREP_PATH ]; then echo "Cannot find [ grep ]. Is it installed? Exiting"; exit 1; fi;

LOGFILE_TMP=$(mktemp)

for i in "${!LIST_TO_DOWNLOAD[@]}"
do
    #echo "key  : $i"
    #echo "value: ${array[$i]}"

    # The download path to the file which contains all the IP addresses
    TO_DOWNLOAD="${LIST_TO_DOWNLOAD[$i]}"

    CHAINNAME=`echo  ${i}|sed 's/\./-/g'` # replace dots by dash to avoid errors

    BLOCKLIST_FILE=$(mktemp)
    BLOCKLIST_TMP_FILE=$(mktemp)

    echo "" >> $LOGFILE_TMP
    echo "Downloading the most recent IP list from $TO_DOWNLOAD ..." >> $LOGFILE_TMP
    wgetOK=$(wget -qO - $TO_DOWNLOAD >> $BLOCKLIST_FILE) >> $LOGFILE_TMP 2>&1
    if [ $? -ne 0 ]; then
            echo "Most recent IP blocklist could not be downloaded from $TO_DOWNLOAD" >> $LOGFILE_TMP
            echo "Please check manually. The script calling this function: $0" >> $LOGFILE_TMP
            if [ "$SEND_MAIL" = true ]
            then
                sudo -u $MAIL_SENDER $MAIL_PATH -s "ERROR - IP blocklist script failed to download the IP set" $MAIL_RECIPIENTS < $LOGFILE_TMP
            fi
            ### Exit with error in this case
            exit 1
    fi

    echo "" >>$LOGFILE_TMP
    echo "Parsing the downloaded file and filter out only IPv4 or CIDR addresses ..." >>$LOGFILE_TMP
    grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/?[0-9]*" $BLOCKLIST_FILE > $BLOCKLIST_TMP_FILE

    echo "" >>$LOGFILE_TMP
    echo "Removing duplicate IPs from the list ..." >>$LOGFILE_TMP
    sort -u $BLOCKLIST_TMP_FILE -o $BLOCKLIST_FILE >>$LOGFILE_TMP 2>&1
    rm $BLOCKLIST_TMP_FILE

    echo "" >>$LOGFILE_TMP
    echo "Setting up the ipset configuration by creating the '$CHAINNAME' IP set ..." >>$LOGFILE_TMP
    if [ `$IPSET_PATH list | grep "Name: $CHAINNAME" | wc -l` -eq 0 ]
    then
            # Create the new ipset set
            echo "ipset configuration does not exists, creating ... " >>$LOGFILE_TMP
            $IPSET_PATH create $CHAINNAME hash:net  >>$LOGFILE_TMP 2>&1
    else
            echo "ipset configuration already exists - Flushing and recreating the iptables/ipset configuration ..." >>$LOGFILE_TMP
            # Reason: The kernel sometimes did not properly flush the ipset list which caused errors. Thus we remove the whole list and recreate it from scatch
            $IPTABLES_PATH --flush $CHAINNAME >>$LOGFILE_TMP 2>&1
            $IPSET_PATH flush $CHAINNAME >>$LOGFILE_TMP 2>&1
            $IPSET_PATH destroy $CHAINNAME >>$LOGFILE_TMP 2>&1
            $IPSET_PATH create $CHAINNAME hash:net  >>$LOGFILE_TMP 2>&1
    fi

    echo "" >>$LOGFILE_TMP
    echo "Setting up the $CHAINNAME chain on iptables, if required..." >>$LOGFILE_TMP
    if [ `$IPTABLES_PATH -L -n | grep "Chain $CHAINNAME" | wc -l` -eq 0 ]
    then
            # Create the iptables chain
            $IPTABLES_PATH --new-chain $CHAINNAME >>$LOGFILE_TMP 2>&1
    fi

    echo "" >>$LOGFILE_TMP
    echo "Inserting the new chain $CHAINNAME into iptables INPUT, if required" >>$LOGFILE_TMP
    # Insert rule (if necesarry) into the INPUT chain so the chain above will also be used
    if [ `$IPTABLES_PATH -L INPUT | grep $CHAINNAME | wc -l` -eq 0 ]
    then
            # Insert rule because it is not present
            $IPTABLES_PATH -I INPUT -j $CHAINNAME >>$LOGFILE_TMP 2>&1
    fi

    # Create rule (if necesarry) into the $CHAINNAME
    echo "" >>$LOGFILE_TMP
    echo "Creating the firewall rule, if required..." >>$LOGFILE_TMP
    if [ `$IPTABLES_PATH -L $CHAINNAME | grep REJECT | wc -l` -eq 0 ]
    then
            # Create the one and only firewall rule
            $IPTABLES_PATH -I $CHAINNAME -m set --match-set $CHAINNAME src -j $ACTION >>$LOGFILE_TMP 2>&1
    fi

    ## Read all IPs from the downloaded IP list and fill up the ipset filter set
    echo "" >>$LOGFILE_TMP
    echo "Importing the IP list into the IP set..." >>$LOGFILE_TMP
    for i in $( cat $BLOCKLIST_FILE )
    do
        if [ "$DEBUG" = true ]
        then
            echo "Adding $i to $CHAINNAME " >>$LOGFILE_TMP
        fi
        $IPSET_PATH add $CHAINNAME $i >>$LOGFILE_TMP 2>&1
    done

    echo "" >>$LOGFILE_TMP
    echo "Done." >>$LOGFILE_TMP
    # cleaning
    rm -f $BLOCKLIST_FILE
    rm -f $BLOCKLIST_TMP_FILE

done

# sending mail
if [ "$SEND_MAIL" = true ]
then
    sudo -u $MAIL_SENDER $MAIL_PATH -s "SUCCESS - IP blocklist script has updated the IP set with the newest IP list" $MAIL_RECIPIENTS < $LOGFILE_TMP
fi

#cleaning
cat $LOGFILE_TMP >> ${LOG_FILE}
rm -f $LOGFILE_TMP
