#!/bin/sh

#
# Properly generates gendate.c from gendate.y
# Requires bison to be found on the system.
#
bison -p gd -o getdate.c getdate.y
