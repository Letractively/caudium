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

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON_DIR=/usr/lib/caudium
DAEMON=$DAEMON_DIR/start
NAME=caudium
DESC="Caudium Webserver"

PIDFILE=/var/run/caudium/caudium.pid
START_OPTIONS="--pid-file=$PIDFILE"

test -f $DAEMON || exit 0

set -e

if test -f /etc/caudium/start_options; then
    START_OPTIONS="$START_OPTIONS `cat /etc/caudium/start_options`"
fi

case "$1" in
  start)
	echo -n "Starting $DESC: "
	cd $DAEMON_DIR
	$DAEMON $START_OPTIONS
	echo "$NAME."
	;;
  stop)
	echo -n "Stopping $DESC: "
	for p in `cat $PIDFILE`; do
    	    kill -TERM $p
	done
	rm -f $PIDFILE
	echo "$NAME."
	;;
  reload|force-reload)
	if test -f $PIDFILE; then
	    echo -n "Restarting $DESC: "
	    for p in `cat $PIDFILE | sed -e 1d`; do
		kill -HUP $p
	    done
	    echo "$NAME."
	else
	    echo "No pidfile found. Cannot reload."
	fi
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

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON_DIR=/usr/lib/caudium
DAEMON=$DAEMON_DIR/start
NAME=caudium
DESC="Caudium Webserver"

PIDFILE=/var/run/caudium/caudium.pid
START_OPTIONS="--pid-file=$PIDFILE"

test -f $DAEMON || exit 0

set -e

if test -f $DAEMON_DIR/.start_options; then
    START_OPTIONS="$START_OPTIONS `cat $DAEMON_DIR/.start_options`"
fi

case "$1" in
  start)
	echo -n "Starting $DESC: "
	cd $DAEMON_DIR
	$DAEMON $START_OPTIONS
	echo "$NAME."
	;;
  stop)
	echo -n "Stopping $DESC: "
	for p in `cat $PIDFILE`; do
    	    kill -9 $p
	done
	echo "$NAME."
	;;
  #reload)
	#
	#	If the daemon can reload its config files on the fly
	#	for example by sending it SIGHUP, do it here.
	#
	#	If the daemon responds to changes in its config file
	#	directly anyway, make this a do-nothing entry.
	#
	# echo "Reloading $DESC configuration files."
	# start-stop-daemon --stop --signal 1 --quiet --pidfile \
	#	/var/run/$NAME.pid --exec $DAEMON
  #;;
  restart|force-reload)
	#
	#	If the "reload" option is implemented, move the "force-reload"
	#	option to the "reload" entry above. If not, "force-reload" is
	#	just the same as "restart".
	#
	echo -n "Restarting $DESC: "
	$0 stop
	sleep 3
	$0 start
	echo "$NAME."
	;;
  *)
	N=$0
	# echo "Usage: $N {start|stop|restart|reload|force-reload}" >&2
	echo "Usage: $N {start|stop|restart|force-reload}" >&2
	exit 1
	;;
esac

exit 0
