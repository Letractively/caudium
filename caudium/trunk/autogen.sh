#!/bin/sh

mydir=`pwd`
for a in . $(find src -name "configure.in" |sort); do
  dir=`dirname $a`
  echo "Running autoconf in '$dir'"
  cd $dir
  (autoheader; autoconf) >/dev/null 2>&1
  cd $mydir
done  
