#!/bin/sh
# FILE: "check_fs.sh"
# DESCRIPTION: Check VNX filesystems
# REQUIRES: 
# AUTHOR: Toni Comerma
# DATE: mar-2013
# $Id:$
#


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
    echo "  -v virtual interface to check, both fsn or trunk. Multiple -v allowed o comma separated list"
    echo "  -p physical interface to check, both fsn or trunk. Multiple -p allowed o comma separated list"
    echo "  -s server to query (server_2 or server_3 or ALL)"
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

W=75
C=90

# Proces de parametres
while getopts "f:w:c:h" Option
do
    case $Option in 
        f ) F="$OPTARG $F";;
        w ) W=$OPTARG;;
        c ) C=$OPTARG;;
		h ) print_help;;		
        * ) echo "unimplemented option";;
        
        esac
done

# Ajustar parametres
F=${F//,/ }
F=`echo $F | sed -e 's/^ *//g' -e 's/ *$//g'`


 # Check filesystems
 for i in $F
 do 
    # Exists?
    /nas/bin/nas_fs -info $i | grep Error > /dev/null
    if [ $? -eq 0 ]
    then
       TEXT="$i:Doesn't Exists $TEXT"
       CRITICAL=1
    else
       # Active?
        /nas/bin/nas_fs -info $i | grep in_use | grep -i true > /dev/null
        if [ $? -eq 1 ]
        then
          TEXT="$i:INACTIVE $TEXT"
          CRITICAL=1
        else
          # Usage
          s=`/nas/bin/nas_fs -info $i -size| grep '^size'`
          pct=`echo $s | cut -f 2 -d "(" | cut -f 1 -d "%"`
          if [ $pct -ge $C ]
          then
             TEXT="$i:$pct%(CRIT) $TEXT"
             CRITICAL=1
          else 
             if [ $pct -ge $W ]
             then
                TEXT="$i:$pct%(WARN) $TEXT"
                WARNING=1
             else 
                TEXT="$i:$pct% $TEXT"
             fi
          fi
        fi
    fi
 done

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
