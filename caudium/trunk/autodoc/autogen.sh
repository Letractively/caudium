#!/bin/sh

# FreeBSD specify hack
if [ -x /usr/local/bin/autoconf213 ];
then
  autoconf213 
else
  autoconf
fi
