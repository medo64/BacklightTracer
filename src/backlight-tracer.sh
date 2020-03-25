#!/bin/bash

if [ -t 1 ]; then
    ESCAPE_RESET="\E[0m"
    ESCAPE_ERROR="\E[31;1m"
    ESCAPE_WARNING="\E[33;1m"
    ESCAPE_CHANGE="\E[37m"
    ESCAPE_RESTORE="\E[36;1m"
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

FILE_INPUT_INCREASE="/run/.backlight-tracer.inc.signal"
FILE_INPUT_DECREASE="/run/.backlight-tracer.dec.signal"

if [ "$EUID" -ne 0 ]; then
    echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: must run as root (try sudo)!${ESCAPE_RESET}" >&2
    exit 254
fi

FILE_DEVICE_BACKLIGHT_BRIGHTNESS="/sys/class/backlight/intel_backlight/brightness"
if [[ ! -e "$FILE_DEVICE_BACKLIGHT_BRIGHTNESS" ]]; then
    echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: cannot find backlight brightness in '$FILE_DEVICE_BACKLIGHT_BRIGHTNESS'!${ESCAPE_RESET}" >&2
    exit 252
fi

FILE_DEVICE_BACKLIGHT_BRIGHTNESS_MAX="/sys/class/backlight/intel_backlight/max_brightness"
if [[ ! -e "$FILE_DEVICE_BACKLIGHT_BRIGHTNESS_MAX" ]]; then
    echo -e "${ESCAPE_WARNING}$SCRIPT_NAME: cannot find maximum backlight brightness in '$FILE_DEVICE_BACKLIGHT_BRIGHTNESS_MAX'${ESCAPE_RESET}" >&2
else
    MAX_BRIGHTNESS=`cat $FILE_DEVICE_BACKLIGHT_BRIGHTNESS_MAX`
    STEP_BRIGHTNESS=$(( $MAX_BRIGHTNESS / 20 ))
    if [[ ! "$STEP_BRIGHTNESS" -gt 0 ]]; then
        echo -e "${ESCAPE_WARNING}$SCRIPT_NAME: cannot determine backlight brightness step in '$FILE_DEVICE_BACKLIGHT_BRIGHTNESS_MAX'${ESCAPE_RESET}" >&2
    fi
fi

if [[ -e /sys/class/power_supply/AC/online ]]; then
    FILE_DEVICE_POWER_ONLINE="/sys/class/power_supply/AC/online"
elif [[ -e /sys/class/power_supply/ACAD/online ]]; then
    FILE_DEVICE_POWER_ONLINE="/sys/class/power_supply/ACAD/online"
else
    echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: cannot find AC status!${ESCAPE_RESET}" >&2
    exit 253
fi


SLEEP_INTERVAL=0.5

STORED_DATA_ADAPTER=`cat $FILE_DATA_ADAPTER 2>/dev/null`
STORED_DATA_BATTERY=`cat $FILE_DATA_BATTERY 2>/dev/null`

if [[ "$STORED_DATA_ADAPTER" != "" ]]; then echo -e "${ESCAPE_CHANGE}Stored adapter backlight is $STORED_DATA_ADAPTER${ESCAPE_RESET}"; fi
if [[ "$STORED_DATA_BATTERY" != "" ]]; then echo -e "${ESCAPE_CHANGE}Stored battery backlight is $STORED_DATA_BATTERY${ESCAPE_RESET}"; fi

while(true); do
    CURR_BRIGHTNESS=`cat $FILE_DEVICE_BACKLIGHT_BRIGHTNESS`
    CURR_ONLINE=`cat $FILE_DEVICE_POWER_ONLINE`
    if [[ "$CURR_ONLINE" != "$LAST_ONLINE" ]]; then
        if [[ "$CURR_ONLINE" != "0" ]]; then
            if [[ "$STORED_DATA_ADAPTER" != "" ]] && [[ "$STORED_DATA_ADAPTER" != "$CURR_BRIGHTNESS" ]]; then
                echo -e "${ESCAPE_RESTORE}Restoring AC backlight to $STORED_DATA_ADAPTER${ESCAPE_RESET}"
                echo $STORED_DATA_ADAPTER > $FILE_DEVICE_BACKLIGHT_BRIGHTNESS
            fi
        else
            if [[ "$STORED_DATA_BATTERY" != "" ]] && [[ "$STORED_DATA_BATTERY" != "$CURR_BRIGHTNESS" ]]; then
                echo -e "${ESCAPE_RESTORE}Restoring battery backlight to $STORED_DATA_BATTERY${ESCAPE_RESET}"
                echo $STORED_DATA_BATTERY > $FILE_DEVICE_BACKLIGHT_BRIGHTNESS
            fi
        fi
        LAST_ONLINE=$CURR_ONLINE
    else
        if [[ "$CURR_ONLINE" != "0" ]]; then
           if [[ "$STORED_DATA_ADAPTER" != "$CURR_BRIGHTNESS" ]]; then
               echo $CURR_BRIGHTNESS > $FILE_DATA_ADAPTER
               STORED_DATA_ADAPTER=$CURR_BRIGHTNESS
               echo -e "${ESCAPE_CHANGE}Updated AC backlight to $CURR_BRIGHTNESS${ESCAPE_RESET}"
           fi
        else
           if [[ "$STORED_DATA_BATTERY" != "$CURR_BRIGHTNESS" ]]; then
               echo $CURR_BRIGHTNESS > $FILE_DATA_BATTERY
               STORED_DATA_BATTERY=$CURR_BRIGHTNESS
               echo -e "${ESCAPE_CHANGE}Updated battery backlight to $CURR_BRIGHTNESS${ESCAPE_RESET}"
           fi
        fi
    fi

    sleep $SLEEP_INTERVAL

    if [[ "$STEP_BRIGHTNESS" -gt 0 ]]; then
        if [[ -e "$FILE_INPUT_DECREASE" ]]; then
            rm "$FILE_INPUT_DECREASE"
            NEW_BRIGHTNESS=$(( $CURR_BRIGHTNESS - $STEP_BRIGHTNESS ))
            if [[ "$NEW_BRIGHTNESS" -lt 1 ]]; then NEW_BRIGHTNESS=1; fi
            if [[ "$NEW_BRIGHTNESS" -ne "$CURR_BRIGHTNESS" ]]; then
                echo "$NEW_BRIGHTNESS" > "$FILE_DEVICE_BACKLIGHT_BRIGHTNESS"
            fi
            SLEEP_INTERVAL=0.1
        elif [[ -e "$FILE_INPUT_INCREASE" ]]; then
            rm "$FILE_INPUT_INCREASE"
            if [[ "$CURR_BRIGHTNESS" -lt "$STEP_BRIGHTNESS" ]]; then
                NEW_BRIGHTNESS=$STEP_BRIGHTNESS
            else
                NEW_BRIGHTNESS=$(( $CURR_BRIGHTNESS + $STEP_BRIGHTNESS ))
                if [[ "$NEW_BRIGHTNESS" -gt "$MAX_BRIGHTNESS" ]]; then NEW_BRIGHTNESS=$MAX_BRIGHTNESS; fi
            fi
            if [[ "$NEW_BRIGHTNESS" -ne "$CURR_BRIGHTNESS" ]]; then
                echo "$NEW_BRIGHTNESS" > "$FILE_DEVICE_BACKLIGHT_BRIGHTNESS"
            fi
            SLEEP_INTERVAL=0.1
        else
            SLEEP_INTERVAL=0.5
        fi
    fi
done
