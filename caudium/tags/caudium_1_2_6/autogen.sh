#!/bin/sh

cd `dirname $0`
pwdir=`pwd`
for a in `find src tools -name "autogen.sh" |sort`; do
  dir=`dirname $a`
  echo "Running autogen in '$dir'"
  cd $dir >/dev/null 2>&1
  ./autogen.sh $pwdir
  cd $pwdir >/dev/null 2>&1
done  

autoconf >/dev/null 2>&1