/*
 * Caudium - An extensible World Wide Web server
 * Copyright <A9> 2000 The Caudium Group
 * Copyright <A9> 1994-2000 Roxen Internet Software
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

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id$";

constant thread_safe = 1;
constant module_name = "Explicit Hostname Redirector";
constant module_doc = "The explicit hostname redirector is designed with only one purpose in mind. The module examines the host header of any incoming request and if it doesn't match one of the hostnames configured in the configuration interface then it redirects the connection to an explicit hostname";
constant module_unique = 1;
constant module_type = MODULE_FIRST;

multiset allowed_hosts = (< >);

void create() {
	defvar( "allowhosts", ({ }), "Allowed Hostnames", TYPE_STRING_LIST, "A comma seperated list of hostname's for which connections will be passed on to the webserver without redirection." );
	defvar( "redirectto", "", "Redirect To", TYPE_STRING, "The hostname to redirect the connection to if it doesn't match one of the hostnames specified. Be careful not to create redirection loops!" );
}

void start() {
	allowed_hosts = mkmultiset( query( "allowhosts" ) );
}

mapping first_try( object id ) {
	if ( allowed_hosts == (< >) ) {
		return 0;
	}
	if ( allowed_hosts[ id->request_headers->host ] ) {
		return 0;
	} else {
		return http_redirect( sprintf( "http://%s%s", query( "redirectto" ), id->raw_url ) );
    	}
}
