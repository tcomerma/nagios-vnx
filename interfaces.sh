#!/bin/sh
# FILE: "check_interfaces.sh"
# DESCRIPTION: Check VNX interfaces, both physical and virtual 
# REQUIRES: 
# AUTHOR: Toni Comerma
# DATE: jan-2013
# $Id:$
#
# Notes
#  - Virtual Interfaces can only be checked against active datamover (server_2)


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
  
	echo "checks interface status"
	echo ""
	echo "Options:"
	echo "	-v virtual interface to check, both fsn or trunk. Multiple -v allowed o comma separated list"
        echo "  -p physical interface to check, both fsn or trunk. Multiple -p allowed o comma separated list"
	echo "	-s server to query (server_2 or server_3 or ALL)"
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
VIRTUAL=""
PHYSICAL=""
SERVER=ALL

# Proces de parametres
while getopts ":v:f:s:h" Option
do
	case $Option in 
		v ) VIRTUAL="$VIRTUAL $OPTARG";;
		f ) PHYSICAL="$PHYSICAL $OPTARG";;
                s ) SERVER=$OPTARG;;
		h ) print_help;;
		* ) echo "unimplemented option";;
		
		esac
done

# Ajustar parametres
PHYSICAL=${PHYSICAL//,/ }
PHYSICAL=`echo $PHYSICAL | sed -e 's/^ *//g' -e 's/ *$//g'`

VIRTUAL=${VIRTUAL//,/ }
VIRTUAL=`echo $VIRTUAL | sed -e 's/^ *//g' -e 's/ *$//g'`

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
 
if [ $SERVER = "ALL" ]
then 
  SERVER="server_3 server_2"
fi

if [ ! -z "$PHYSICAL" ]
then 
  for j in $SERVER
  do 
    # Comprovar interfaces fisics
    for i in $PHYSICAL
    do
      /nas/bin/server_sysconfig $j -pci $i | grep "$i" >/dev/null
      if [ $? -ne 0 ]
      then
        TEXT="$i:INEXIST $TEXT"     
      else
         status=`/nas/bin/server_sysconfig $j -pci $i | grep "Link:" | cut -f 2 -d ":"`
         if [ "$status" = " Up " ]
         then
           TEXT="$i:OK $TEXT"
         else
           TEXT="$i:$status $TEXT"
           CRITICAL=1
         fi
      fi
    done
  TEXT="$j->$TEXT"
  done
fi

for i in $VIRTUAL
 do
 # Comprovar interfaces virtuals (nomes server_2)
 status=`/nas/bin/server_sysconfig server_2 -virtual -info $i |  grep "Link is " | cut -f 6 -d " " `
 if [ "$status" = "Up" ]
 then
    # Es FSN O TRK
    type=`/nas/bin/server_sysconfig server_2 -virtual -info $i |  grep -F "***" | cut -f 2 -d " " `
    if [ "$type" = "FSN" ]
    then
       # FSN
       primary=`/nas/bin/server_sysconfig server_2 -virtual -info $i |  grep primary | cut -f 2 -d " " | cut -f 2 -d "="`
       active=`/nas/bin/server_sysconfig server_2 -virtual -info $i |  grep primary | cut -f 1 -d " " | cut -f 2 -d "="`
       if [ "$primary" = "$active" ] 
       then
         TEXT="$i:OK $TEXT"  
       else
         TEXT="$i:FAILOVER $TEXT"
         WARNING=1
       fi
    else
       # TRK
        status=`/nas/bin/server_sysconfig server_2 -virtual -info $i | tail -n +3 | grep -i "down" | cut -f 1 -d " " `
       if [ "$status" != "" ]
       then
         TEXT="$i:OK $TEXT"
       else
         TEXT="$i:WARNING($status) $TEXT"
         WARNING=1
       fi
    fi
 else
    TEXT="$i:$status $TEXT"
    CRITICAL=1
 fi
done
TEXT="server_2->$TEXT"

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
