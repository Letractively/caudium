#!/bin/sh
make spotless
./autogen.sh
./configure --with-pikesrc=/usr/local/src/Pike-v7.4.10 --with-pike=/usr/local/pike74/bin/pike
make
