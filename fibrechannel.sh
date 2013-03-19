#!/bin/sh
# FILE: "pools.sh"
# DESCRIPTION: Check VNX fibre channel (from SPA and SPB)
# REQUIRES: 
# AUTHOR: Toni Comerma
# DATE: mar-2013
# $Id:$
#
# Notes:


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
  
    echo "checks fibre channel"
    echo ""
    echo "Options:"
    echo "  -p fibre channel port/s ID. Multiple -p allowed o comma separated list"
    echo "  Note: It will check SP A and SP B"
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
TEXT_ERR=""
TMP=$PROGPATH/fibrechannel.tmp

# Proces de parametres
while getopts "p:h" Option
do
    case $Option in 
        p ) PORTS="$OPTARG $PORTS";;
	    h ) print_help;;
        * ) echo "unimplemented option";;
        
        esac
done

# Ajustar parametres
PORTS=${PORTS//,/ }
PORTS=`echo $PORTS | sed -e 's/^ *//g' -e 's/ *$//g'`


 # Check FC ports
 # try SP A
 /nas/sbin/navicli -h vnx01-spa getall -hba | awk -F ":" '/SP Name/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);sp=$2 }
                                                              /Link Status/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);l=$2 }
                                                              /SP Port ID/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);id=$2 }															  
															  /Port Status/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);p=$2; {print sp",ID="id": Link="l",Port="p} }' > $TMP 2> /dev/null
 if [ $? -ne 0 ]
 then
    #try SP b
    /nas/sbin/navicli -h vnx01-spa getall -hba | awk -F ":" '/SP Name/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);sp=$2 }
                                                              /Link Status/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);l=$2 }
                                                              /SP Port ID/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);id=$2 }															  
															  /Port Status/ { gsub(/^[ \t]+|[ \t]+$/, "", $2);p=$2; {print sp",ID="id": Link="l",Port="p} }' > $TMP 2> /dev/null
    if [ $? -ne 0 ]
	then
	  CRITICAL=1
	  TEXT_ERR="Unable to contact SP A or SP B"
	else
	  WARNING=1
	  	  TEXT_ERR="Unable to contact SP A"
	fi
 fi
 if [ $CRITICAL -eq 0 ]
 then
     # Loop SP's
	 for sp in "SP A" "SP B"
	 do
		 for i in $PORTS
		 do 
			# Exists?
			status=`grep "ID=$i" $TMP | grep "$sp"`
			if [ $? -ne 0 ]
			then
			   TEXT_ERR="$i:Doesn't Exists  $TEXT"
			   CRITICAL=1
			else
			   # Active?
			   status=`grep "ID=$i" $TMP  | grep "$sp" | grep Up `
				if [ $? -ne 0 ]
				then
				  status=`grep "ID=$i" $TMP  | grep "$sp" | tr '\n' ' '`
				  TEXT_ERR="$status $TEXT"
				  WARNING=$(($WARNING + 1))
				else
				  status=`grep "ID=$i" $TMP  | grep "$sp" | tr '\n' ' '`
				  TEXT="$status $TEXT"
				fi
			fi
		 done
	   done
     fi
    rm -f $TMP
    if [ $CRITICAL -eq 1 -o $WARNING -gt 1 ]
    then
      echo "CRITICAL: $TEXT_ERR $TEXT"
      exit $STATE_CRITICAL
    fi
    
    if [ $WARNING -eq 1 ]
    then
      echo "WARNING: $TEXT_ERR $TEXT"
      exit $STATE_WARNING
    fi
    
    echo "OK: $TEXT"
    exit $STATE_OK 
    