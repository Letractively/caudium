#!/bin/sh

PORTCHECK='object port = Stdio.Port(); if (!port->bind((int)getenv("PORTNO"))) write("no"); else write("yes");'

P=80
RET=`env PORTNO=$P /usr/bin/pike7 -e "$PORTCHECK"`
if test "$RET" = "no"; then
    echo $P unavailable
else
    echo $P available
fi

P=8080
RET=`env PORTNO=$p /usr/bin/pike7 -e "$PORTCHECK"`
if test "$RET" = "no"; then
    echo $P unavailable
else
    echo $P available
fi
