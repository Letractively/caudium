/*
 * Caudium - An extensible World Wide Web server
 * Copyright C 2000-2002 The Caudium Group
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

/*
 * The Caudium/CAMAS ESMTP client module
 *
 * This class implements the asynchronous smtp client.
 *
 */


constant cvs_version = "$Id$";

#define CODECLASS(X)    ( ((smtp_reply->retcode / 100) * 100 == X) ? 1 : 0 )

import ".";
inherit client;

private mapping transaction = ([
	"auth":		({ }),
	"trans":	([
				"headers":	({ }),
				"body":		({ })
	]),
	"leave":	({ })
]);						// what to send to the server, broken up by sections

private mapping smtp_server = ([
	"address":	"127.0.0.1",
	"port":		25,
	"fqdn":		""
]);						// the remote side we'll connect to

private mapping supports = ([
	"esmtp":	0,
	"tls":		0,
	"auth":	([
			"yes": 0,
			"methods": ({ })
	]),
	"size":		0,
	"dsn":		0
]);						// server capability list

private mapping this_connection = ([
	"active":		0,
	"esmtp":		0,
	"tls":			0,
	"authenticated":	0,
	"dsn":			0,
	"size":			0
]);						// current connection's properties

void create(void|string server, void|string|int port, void|string maildomain) {
	if(server && stringp(server))
		smtp_server->address = server;
	if(port && intp(port)) {
		smtp_server->port = port;
	} else if (port && stringp(port)) {
		int tmp = Protocols.Ports.tcp[port];
		smtp_server->port = ( tmp == 0 ? 25 : tmp );
	} else if(port < 1 || port > 65534) {
		port = 25;
	};
	smtp_server->fqdn = (maildomain && stringp(maildomain)) ? gethostname() + "." + maildomain : gethostname();
}


