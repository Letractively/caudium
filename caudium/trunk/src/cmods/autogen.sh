#!/bin/sh

# FreeBSD specify hack
if [ -x /usr/local/bin/autoconf213 ];
then
  autoconf213 --localdir=$1
else
  autoconf --localdir=$1
fi
