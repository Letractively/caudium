#!/bin/sh
# full destination _top directory_ path
TO="$1"

# links filename for dh_link input
LINKSFILE="$2"

# prefix to substract from the original paths
PREFIX="$3"

# chroot
CHROOT="$4"


if [ -z "$TO" -o -z "$LINKSFILE" -o -z "$PREFIX" ]; then
    echo This script requires at least three arguments - TO, LINKSFILE and PREFIX
    exit 1
fi

read FPATH
while [ -n "$FPATH" ]; do
    FROM="`echo "$FPATH" | sed -e \"s;$PREFIX;;g\"`"
    install -d -m 755 -o root -g root $CHROOT`dirname /$TO/$FROM`
    echo $TO$FROM $FPATH >> $LINKSFILE
    if [ -f "$FPATH" ]; then
       mv $FPATH $CHROOT/$TO/$FROM   
    fi
    read FPATH
done
exit 0
