#!/bin/bash

SCRIPT_NAME="backlight-tracer"
PID_FILE="/run/$SCRIPT_NAME.pid"
PID_LAST=`cat $PID_FILE 2>/dev/null`
if [ -n "$PID_LAST" ]; then
    PID_ACTIVE=`ps -ax $PID_LAST | grep "^ *$PID_LAST" | grep "$SCRIPT_NAME"`
    if [ -n "$PID_ACTIVE" ]; then
        touch /tmp/.backlight-tracer.inc.signal
    fi
fi
