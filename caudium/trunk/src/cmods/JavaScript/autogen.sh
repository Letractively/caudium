#!/bin/sh

# FreeBSD specify hack
if [ -x /usr/local/bin/autoconf213 ];
then
  autoheader213
  autoconf213 --localdir=$1
else
  autoheader
  autoconf --localdir=$1
fi
