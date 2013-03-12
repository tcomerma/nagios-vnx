#!/bin/sh
# FILE: "check_hardware.sh"
# DESCRIPTION: Check VNX hardware
# REQUIRES: 
# AUTHOR: Toni Comerma
# DATE: mar-2013
# $Id:$
#
# Notes


PROGNAME=`readlink -f $0`
PROGPATH=`echo $PROGNAME | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
export NAS_DB=/nas

print_usage() {
  echo "Usage:"
  echo "  $PROGNAME  "
  echo "  $PROGNAME -h "

  
}

print_help() {
  print_revision $PROGNAME $REVISION
  echo ""
  print_usage
  
	echo "checks hardware status using enclosure_status & nas_inventory"
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

# Proces de parametres
while getopts "h" Option
do
	case $Option in 
		h ) print_help;;
		* ) echo "unimplemented option";;
		
		esac
done

# Check 1

HW=`/nas/sbin/enclosure_status -e 0 -v|grep -ci "failed"`
if [ "$HW" -gt 0 ]
 then
  TEXT="Enclosure: $HW"
  CRITICAL=1
fi


# Check 2
HW=`/nas/sbin/nas_inventory -info -all | awk -F '=' '/Component Name/ { c=$2 }
                                /Status/         { s=$2 ; if (s != " OK") {print c":"s}}' `
if [ ! -z "$HW" ]
 then
  TEXT="$HW"
  CRITICAL=1
  echo $HW
fi

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

echo "OK: Hardware ready"
exit $STATE_OK 
