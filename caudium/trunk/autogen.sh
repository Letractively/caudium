#!/bin/sh

mydir=`pwd`
for a in `find src -name "autogen.sh" |sort`; do
  dir=`dirname $a`
  echo "Running autogen in '$dir'"
  cd $dir
  ./autogen.sh 
  cd $mydir
done  

autoconf >/dev/null 2>&1