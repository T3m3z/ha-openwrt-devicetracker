#!/bin/ash

IFNAME=${2#"IFNAME="}
EVENT=$3
MAC=$4
DEVICE=$(cat /proc/sys/kernel/hostname)

BASEURL=https://home-assistant.address.com/api/webhook/ # <- CHANGE THIS, USE HTTPS WHENEVER POSSIBLE
WEBHOOKID=VERY-LONG-UNIQUE-ID # <- CHANGE THIS, USE LONG ID, TREAT LIKE PASSWORD

send_event() {
  wget -qO- --header="Content-Type: application/json" --post-data="{\"mac\": \"$MAC\", \"state\": \"$1\", \"source\": \"$DEVICE-$IFNAME\"}" $BASEURL$WEBHOOKID > /dev/null
}

if [[ $EVENT == "<3>AP-STA-CONNECTED" ]]
then
  send_event "home"
fi

if [[ $EVENT == "<3>AP-STA-DISCONNECTED" ]]
then
  send_event "not_home"
fi
