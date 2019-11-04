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
trap "echo -ne '${ESCAPE_RESET}' ; rm $PID_FILE 2> /dev/null" EXIT SIGHUP SIGINT SIGTERM
trap "exit 1" INT


FILE_AC="/var/cache/.backlight-tracer.ac"
FILE_BAT="/var/cache/.backlight-tracer.bat"
FILE_SOURCE="/sys/class/power_supply/AC/online"
FILE_BRIGHTNESS="/sys/class/backlight/intel_backlight/brightness"


if [ "$EUID" -ne 0 ]; then
    echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: must run as root (try sudo)!${ESCAPE_RESET}" >&2
    exit 254
fi

if [[ ! -e "$FILE_SOURCE" ]]; then
    echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: cannot find AC status in '$FILE_SOURCE'!${ESCAPE_RESET}" >&2
    exit 253
fi

if [[ ! -e "$FILE_BRIGHTNESS" ]]; then
    echo -e "${ESCAPE_ERROR}$SCRIPT_NAME: cannot find backlight brightness in '$FILE_BRIGHTNESS'!${ESCAPE_RESET}" >&2
    exit 252
fi


STORED_AC=`cat $FILE_AC 2>/dev/null`
STORED_BAT=`cat $FILE_BAT 2>/dev/null`

if [[ "$STORED_AC" != "" ]]; then echo -e "${ESCAPE_CHANGE}Stored AC backlight is $STORED_AC${ESCAPE_RESET}"; fi
if [[ "$STORED_BAT" != "" ]]; then echo -e "${ESCAPE_CHANGE}Stored battery backlight is $STORED_BAT${ESCAPE_RESET}"; fi

while(true); do
    BRIGHTNESS=`cat $FILE_BRIGHTNESS`
    CURR_AC=`cat $FILE_SOURCE`
    if [[ "$CURR_AC" != "$LAST_AC" ]]; then
        if [[ "$CURR_AC" != "0" ]]; then
            if [[ "$STORED_AC" != "" ]] && [[ "$STORED_AC" != "$BRIGHTNESS" ]]; then
                echo -e "${ESCAPE_RESTORE}Restoring AC backlight to $STORED_AC${ESCAPE_RESET}"
                echo $STORED_AC > $FILE_BRIGHTNESS
            fi
        else
            if [[ "$STORED_BAT" != "" ]] && [[ "$STORED_BAT" != "$BRIGHTNESS" ]]; then
                echo -e "${ESCAPE_RESTORE}Restoring battery backlight to $STORED_BAT${ESCAPE_RESET}"
                echo $STORED_BAT > $FILE_BRIGHTNESS
            fi
        fi
        LAST_AC=$CURR_AC
    else
        if [[ "$CURR_AC" != "0" ]]; then
           if [[ "$STORED_AC" != "$BRIGHTNESS" ]]; then
               echo $BRIGHTNESS > $FILE_AC
               STORED_AC=$BRIGHTNESS
               echo -e "${ESCAPE_CHANGE}Updated AC backlight to $BRIGHTNESS${ESCAPE_RESET}"
           fi
        else
           if [[ "$STORED_BAT" != "$BRIGHTNESS" ]]; then
               echo $BRIGHTNESS > $FILE_BAT
               STORED_BAT=$BRIGHTNESS
               echo -e "${ESCAPE_CHANGE}Updated battery backlight to $BRIGHTNESS${ESCAPE_RESET}"
           fi
        fi
    fi

    sleep 0.5
done

