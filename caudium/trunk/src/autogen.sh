#!/bin/sh

# FreeBSD specify hack
if [ -x /usr/local/bin/autoconf213 ];
then
  autoconf213 >/dev/null 2>&1
else
  autoconf >/dev/null 2>&1
fi

