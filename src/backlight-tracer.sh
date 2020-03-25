#!/bin/bash

if [ -t 1 ]; then
    ESCAPE_RESET="\E[0m"
    ESCAPE_ERROR="\E[31;1m"
    ESCAPE_CHANGE="\E[37m"
    ESCAPE_RESTORE="\E[33;1m"
fi


SCRIPT_NAME=`basename $0`
PID_FILE="/run/$SCRIPT_NAME.pid"
PID_LAST=`cat $PID_FILE 2>/dev/null`
if [ -n "$PID_LAST" ]; then
    PID_ACTIVE=`ps -ax $PID_LAST | grep "^$PID_LAST" | grep "$SCRIPT_NAME"`
    if [ -n "$PID_ACTIVE" ]; then
        echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: script is already running!${ESCAPE_RESET}" >&2
        exit 255
    fi
fi
echo $$ > $PID_FILE
trap "echo -ne '${ESCAPE_RESET}' ; rm $PID_FILE 2> /dev/null; exit 0" EXIT INT KILL SIGHUP SIGINT SIGKILL SIGTERM


FILE_DATA_ADAPTER="/var/cache/.backlight-tracer.adapter.dat"
FILE_DATA_BATTERY="/var/cache/.backlight-tracer.battery.dat"

if [ "$EUID" -ne 0 ]; then
    echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: must run as root (try sudo)!${ESCAPE_RESET}" >&2
    exit 254
fi

FILE_DEVICE_BACKLIGHT_BRIGHTNESS="/sys/class/backlight/intel_backlight/brightness"
if [[ ! -e "$FILE_DEVICE_BACKLIGHT_BRIGHTNESS" ]]; then
    echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: cannot find backlight brightness in '$FILE_DEVICE_BACKLIGHT_BRIGHTNESS'!${ESCAPE_RESET}" >&2
    exit 252
fi

if [[ -e /sys/class/power_supply/AC/online ]]; then
    FILE_DEVICE_POWER_ONLINE="/sys/class/power_supply/AC/online"
elif [[ -e /sys/class/power_supply/ACAD/online ]]; then
    FILE_DEVICE_POWER_ONLINE="/sys/class/power_supply/ACAD/online"
else
    echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: cannot find AC status!${ESCAPE_RESET}" >&2
    exit 253
fi


STORED_DATA_ADAPTER=`cat $FILE_DATA_ADAPTER 2>/dev/null`
STORED_DATA_BATTERY=`cat $FILE_DATA_BATTERY 2>/dev/null`

if [[ "$STORED_DATA_ADAPTER" != "" ]]; then echo -e "${ESCAPE_CHANGE}Stored adapter backlight is $STORED_DATA_ADAPTER${ESCAPE_RESET}"; fi
if [[ "$STORED_DATA_BATTERY" != "" ]]; then echo -e "${ESCAPE_CHANGE}Stored battery backlight is $STORED_DATA_BATTERY${ESCAPE_RESET}"; fi

while(true); do
    BRIGHTNESS=`cat $FILE_DEVICE_BACKLIGHT_BRIGHTNESS`
    CURR_ADAPTER=`cat $FILE_DEVICE_POWER_ONLINE`
    if [[ "$CURR_ADAPTER" != "$LAST_ADAPTER" ]]; then
        if [[ "$CURR_ADAPTER" != "0" ]]; then
            if [[ "$STORED_DATA_ADAPTER" != "" ]] && [[ "$STORED_DATA_ADAPTER" != "$BRIGHTNESS" ]]; then
                echo -e "${ESCAPE_RESTORE}Restoring AC backlight to $STORED_DATA_ADAPTER${ESCAPE_RESET}"
                echo $STORED_DATA_ADAPTER > $FILE_DEVICE_BACKLIGHT_BRIGHTNESS
            fi
        else
            if [[ "$STORED_DATA_BATTERY" != "" ]] && [[ "$STORED_DATA_BATTERY" != "$BRIGHTNESS" ]]; then
                echo -e "${ESCAPE_RESTORE}Restoring battery backlight to $STORED_DATA_BATTERY${ESCAPE_RESET}"
                echo $STORED_DATA_BATTERY > $FILE_DEVICE_BACKLIGHT_BRIGHTNESS
            fi
        fi
        LAST_ADAPTER=$CURR_ADAPTER
    else
        if [[ "$CURR_ADAPTER" != "0" ]]; then
           if [[ "$STORED_DATA_ADAPTER" != "$BRIGHTNESS" ]]; then
               echo $BRIGHTNESS > $FILE_DATA_ADAPTER
               STORED_DATA_ADAPTER=$BRIGHTNESS
               echo -e "${ESCAPE_CHANGE}Updated AC backlight to $BRIGHTNESS${ESCAPE_RESET}"
           fi
        else
           if [[ "$STORED_DATA_BATTERY" != "$BRIGHTNESS" ]]; then
               echo $BRIGHTNESS > $FILE_DATA_BATTERY
               STORED_DATA_BATTERY=$BRIGHTNESS
               echo -e "${ESCAPE_CHANGE}Updated battery backlight to $BRIGHTNESS${ESCAPE_RESET}"
           fi
        fi
    fi

    sleep 0.5
done

