#! /bin/sh
#
# skeleton	example file to build /etc/init.d/ scripts.
#		This file should be used to construct scripts for /etc/init.d.
#
#		Written by Miquel van Smoorenburg <miquels@cistron.nl>.
#		Modified for Debian GNU/Linux
#		by Ian Murdock <imurdock@gnu.ai.mit.edu>.
#
# Version:	@(#)skeleton  1.8  03-Mar-1998  miquels@cistron.nl
#
# This file was automatically customized by dh-make on Tue, 15 Aug 2000 13:47:27 +0200
#
# Caudium init.d startup file
#
# $Id$
EXTVER=
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON_DIR=/usr/lib/caudium${EXTVER}
DAEMON=$DAEMON_DIR/start-caudium
NAME=caudium${EXTVER}
DESC="Caudium Webserver"

PIDFILE=/var/run/caudium${EXTVER}/caudium.pid
DEFSTART_OPTIONS="--pid-file=$PIDFILE --config-dir=/etc/caudium${EXTVER}/servers/ --log-dir=/var/log/caudium${EXTVER}/"

test -f $DAEMON || exit 0

set -e

if test -f /etc/default/caudium${EXTVER}; then
    . /etc/default/caudium${EXTVER}
fi

case "$1" in
  start)
   echo -n "Starting $DESC: "
   start-stop-daemon --pidfile $PIDFILE --quiet --chdir $DAEMON_DIR \
      --exec $DAEMON -- $DEFSTART_OPTIONS $START_OPTIONS > /dev/null
   echo "$NAME."
	;;
  stop)
    echo -n "Stopping $DESC: "
    start-stop-daemon --stop --pidfile $PIDFILE --signal 15 --oknodo --retry 10 --chdir $DAEMON_DIR \
       --exec $DAEMON
    rm -f $PIDFILE
    echo "$NAME."
	;;
  reload|force-reload)
    start-stop-daemon --stop --pidfile $PIDFILE --signal 1 --oknodo --chdir $DAEMON_DIR \
       --exec $DAEMON
	;;
  restart)
	#
	#	If the "reload" option is implemented, move the "force-reload"
	#	option to the "reload" entry above. If not, "force-reload" is
	#	just the same as "restart".
	#
	$0 stop
	sleep 3
	$0 start
	;;
  *)
	N=$0
	# echo "Usage: $N {start|stop|restart|reload|force-reload}" >&2
	echo "Usage: $N {start|stop|restart|force-reload}" >&2
	exit 1
	;;
esac

exit 0
