#!/bin/sh

# FreeBSD specify hack
if [ -x /usr/local/bin/autoconf213 ];
then
  autoheader213
  autoconf213 
else
  autoheader
  autoconf
fi
