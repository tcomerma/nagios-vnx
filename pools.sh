#!/bin/sh
# FILE: "pools.sh"
# DESCRIPTION: Check VNX pools
# REQUIRES: 
# AUTHOR: Toni Comerma
# DATE: mar-2013
# $Id:$
#
# Note: If pool name has spaces, you have to quote it


PROGNAME=`readlink -f $0`
PROGPATH=`echo $PROGNAME | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
export NAS_DB=/nas

print_usage() {
  echo "Usage:"
  echo "  $PROGNAME -v <virt> -f <phys> -s <server> "
  echo "  $PROGNAME -h "

  
}

print_help() {
  print_revision $PROGNAME $REVISION
  echo ""
  print_usage
  
    echo "checks pools"
    echo ""
    echo "Options:"
    echo "  -p pool ID"
    echo "  -w XX Percentage used warning level (default 65%)"
    echo "  -c XX Percentage used critical level (default 80%)"
    echo "  -W XX Percentage Subcribed warning level (default 125%)"
    echo "  -C XX Percentage Subscribed critical level (default 150%)"
    echo ""
  exit $STATE_UNKNOWN
}



STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

WARNING=0
CRITICAL=0
TEXT=""
w=65
c=80
W=125
C=150
TMP=$PROGPATH/pools.tmp

# Proces de parametres
while getopts "p:w:c:W:C:h" Option
do
    case $Option in 
        p ) p="$OPTARG $F";;
        w ) w=$OPTARG;;
        c ) c=$OPTARG;;
        W ) W=$OPTARG;;
        C ) C=$OPTARG;;
	    h ) print_help;;
        * ) echo "unimplemented option";;
        
        esac
done

# Ajustar parametres
p=${p//,/ }
p=`echo $p | sed -e 's/^ *//g' -e 's/ *$//g'`

# Checking Control Station Status (primary/standby)
MCDHOME=/nasmcd
RC_CS_IS_STANDBY=11
RC_CS_IS_PRIMARY=10

slot=`$MCDHOME/sbin/t2slot`
peer=$(( $slot == 0 ? 1 : 0 ))
ret=`$MCDHOME/sbin/getreason | grep -w slot_$slot`
rc=`echo $ret | cut -d- -f1`
status=`echo $ret | cut -d- -f2`

if [ $rc -eq $RC_CS_IS_STANDBY ]
 then
    echo "OK: Standby Control Station - Not Monitoring"
    exit $STATE_OK 
 else
   if [ $rc -ne $RC_CS_IS_PRIMARY ]
   then
      echo "CRITICAL: Unknown Control Station Status (not primary, not standby) take a look"
      exit $STATE_CRITICAL
   fi
 fi
 
# try SP A
 /nas/sbin/navicli -h vnx01-spa storagepool -list | awk -F ":" '/Pool Name/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);p=$2 }
                                                              /^Pool ID/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);id=$2 }
                                                              /^Status/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);st=$2 }
                                                              /Percent Full/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);f=$2 }															  
															  /Percent Subscribed/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);s=$2; {print p"(ID="id"):Status="st",Used="f"%,Subscribed="s"%"} }' > $TMP 2> /dev/null
 if [ $? -ne 0 ]
 then
    #try SP b
    /nas/sbin/navicli -h vnx01-spb storagepool -list | awk -F ":" '/Pool Name/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);p=$2 }
                                                              /^Pool ID/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);id=$2 }
                                                              /^Status/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);st=$2 }
                                                              /Percent Full/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);f=$2 }															  
															  /Percent Subscribed/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);s=$2; {print p"(ID="id"):Status="st",Used="f"%,Subscribed="s"%"} }' > $TMP 2> /dev/null
    if [ $? -ne 0 ]
	then
	  CRITICAL=1
	  TEXT="Unable to contact SP A or SP B"
	else
	  WARNING=1
	  	  TEXT="Unable to contact SP A"
	fi
 fi

if [ $CRITICAL -eq 0 ]
 then
 # Check pools
 for i in $p
 do 
    # Exists?
    status=`grep "ID=$p" $TMP`
    if [ $? -ne 0 ]
    then
       TEXT="ID=$p:Doesn't Exists $TEXT"
       CRITICAL=1
    else
       # Active?
        status=`grep "ID=$p" $TMP | grep OK `
        if [ $? -eq 1 ]
        then
          TEXT="$p:FAILED $TEXT"
          CRITICAL=1
        else
          # Usage
		  used=`grep "ID=$p" $TMP | cut -f 4 -d "=" | cut -f 1 -d "."`
          if [ $used -ge $c ]
          then
             TEXT="$status(Usage CRITICAL) $TEXT"
             CRITICAL=1
          else 
             if [ $used -ge $w ]
             then
                TEXT="$status(Usage WARNING) $TEXT"
                WARNING=1
             else 
 		        # Subscription
		        subs=`grep "ID=$p" $TMP | cut -f 5 -d "=" | cut -f 1 -d "."`
                if [ $subs -ge $C ]
                then
                   TEXT="$status(Subscription CRITICAL) $TEXT"
                   CRITICAL=1
                else 
                   if [ $subs -ge $W ]
                   then
                      TEXT="$status(Subscription WARNING) $TEXT"
                      WARNING=1
                    else 
                      TEXT="$status $TEXT"
                    fi
                fi
			 fi
          fi
        fi
	fi	
 done
fi
rm -f $TMP
if [ $CRITICAL -eq 1 ]
then
  echo "CRITICAL: $TEXT"
  exit $STATE_CRITICAL
fi

if [ $WARNING -eq 1 ]
then
  echo "WARNING: $TEXT"
  exit $STATE_WARNING
fi

echo "OK: $TEXT"
exit $STATE_OK 
