#!/bin/bash
#-------------------------------------------------#
# L2TP_IP44=true // AMPRNet IP44 internet gateway #
#                                                 #
# L2TP_IP44=false // Normal internet gateway      #
#-------------------------------------------------#
L2TP_IP44=true

#------------------------#
# Config system variable #
#------------------------#
ECHO=/usr/bin/echo
IP=/usr/sbin/ip
ROUTE=/usr/sbin/route
GREP=/usr/bin/grep
AWK=/usr/bin/awk
IFCONFIG=/usr/sbin/ifconfig
SERVICE=/usr/sbin/service
IPSEC=/usr/sbin/ipsec
L2TP_CONTROL=/var/run/xl2tpd/l2tp-control

#-----------------------------------------------#
# L2TP_SERVER is gw01.ham.in.th = 119.59.96.112 #
#-----------------------------------------------#
L2TP_SERVER="119.59.96.112"
PPP_DEV="ppp0"

#------------------------------------------#
# If use Echolink SERVICE_NAME = "svxlink" #
# If use AllStar Link SERVICE_NAME = ""    #
#------------------------------------------#
SERVICE_NAME="svxlink"

#------------------------#
# Get dynamic variable   #
#------------------------#
PPP0=$($ROUTE -n | $GREP $PPP_DEV | $AWK '{print $8}')
DEFAULT_GW=$($ROUTE -n | $GREP "0.0.0.0" | head -1 | $GREP $PPP_DEV | $AWK '{print $8}')
GATEWAY=$($ROUTE -n | $GREP "0.0.0.0" | head -1 | $AWK '{print $2}')
ROUTE_L2TP=$($ROUTE -n | $GREP "^"$L2TP_SERVER | $AWK '{print $1}')
if [ ! -z "$SERVICE_NAME" ]
then
  SERVICE_STATUS=$($SERVICE $SERVICE_NAME status | $GREP running | $AWK '{print $3}')
else
  SERVICE_STATUS=""
fi

#----------------------------------------------#
# If AMPRNet IP44 is enable to default gateway #
#----------------------------------------------#
if [ "$L2TP_IP44" == 'true' ]
then
  if [ ! -z "$PPP0" ]
    then
    echo $PPP_DEV" is up."
    if [ -z "$DEFAULT_GW" ]
    then
      echo $PPP_DEV" is not default gateway, Try to change it…"
      echo "d myvpn" > $L2TP_CONTROL
      if [ ! -z "$SERVICE_NAME" ]
      then
        if [ ! -z "$SERVICE_STATUS" ]
        then
          echo "Stop service "$SERVICE_NAME"…"
          $SERVICE $SERVICE_NAME stop
          sleep 2
        fi
      fi

      echo "Check routing…"
      if [ -z "$ROUTE_L2TP" ]
      then
        echo "Add route L2TP Server to master gateway."
        $IP route add $L2TP_SERVER via $GATEWAY
      else
        echo "Already have route to L2TP Server."
      fi
 
      $IPSEC up L2TP-PSK
      echo "c myvpn" > $L2TP_CONTROL
      sleep 3
      $IP route add 0.0.0.0/0 dev $PPP_DEV metric 0

      if [ ! -z "$SERVICE_NAME" ]
      then
        echo "Start service "$SERVICE_NAME"…"
        $SERVICE $SERVICE_NAME start
      fi
    else
      echo $PPP_DEV" is default gateway."
      echo $PPP_DEV" ip "$($IFCONFIG $PPP_DEV | $GREP "inet" | $AWK '{print $2}')
    fi
  else
    echo "ppp0 is down, Try to up…"
    echo "d myvpn" > $L2TP_CONTROL
    $IPSEC down L2TP-PSK
    if [ ! -z "$SERVICE_NAME" ]
    then
      if [ ! -z "$SERVICE_STATUS" ]
      then
        echo "Stop service "$SERVICE_NAME"…"
        $SERVICE $SERVICE_NAME stop
        sleep 2
      fi
    fi

    echo "Check internet gateway…"
    ping -c 1 8.8.8.8
    rc=$?
    if [[ $rc -eq 0 ]]
    then
      echo "Internet gateway is up."

      if [ -z "$ROUTE_L2TP" ]
      then
        echo "Add route L2TP Server to master gateway."
        $IP route add $L2TP_SERVER via $GATEWAY
      fi

      $IPSEC up L2TP-PSK
      echo "c myvpn" > $L2TP_CONTROL
      echo "Add "$PPP_DEV" to default gateway."
      sleep 3
      $IP route add 0.0.0.0/0 dev $PPP_DEV metric 0
      if [ ! -z "$SERVICE_NAME" ]
      then
        echo "Start service "$SERVICE_NAME"…"
        $SERVICE $SERVICE_NAME start
      fi
    else
      echo "Internet gateway is down."
    fi
  fi
else
  echo "Use normal gateway…"
  if [ ! -z "$PPP0" ]
  then
    echo $PPP_DEV" is up, Try to down now…"
    echo "d myvpn" > $L2TP_CONTROL
    $IPSEC down L2TP-PSK
    $IP route del $L2TP_SERVER via $GATEWAY
  fi
fi
