/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000 The Caudium Group
 * Copyright � 1994-2000 Roxen Internet Software
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

//
//! module: HTTP-Relay
//!  Relays HTTP requests from this server to another one. <p>
//!  Like the redirect module, but transparent to the user. This module
//!  will connect to another server, and get the data from there, and
//!  then return the new data to the user.  The same results can be
//!  achieved using the proxy and the redirect module.  With
//!  caching. This module is therefore quite obsolete, really. But
//!  since it is so small, I have left it here.</p>
//! inherits: module
//! inherits: caudiumlib
//! inherits: socket
//! type: MODULE_LAST | MODULE_FIRST
//! cvs_version: $Id$
//

// Like the redirect module, but transparent to the user. This module
// will connect to another server, and get the data from there, and
// then return the new data to the user.  The same results can be
// achieved using the proxy and the redirect module.  With
// caching. This module is therefore quite obsolete, really.  But
// since it is so small, I have left it here.

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>

inherit "module";
inherit "caudiumlib";
inherit "socket";

constant module_type = MODULE_LAST | MODULE_FIRST;
constant module_name = "HTTP-Relay";
constant module_doc  = "Relays HTTP requests from this server to another one. <p>"
      "Like the redirect module, but transparent to the user. This module "
      "will connect to another server, and get the data from there, and "
      "then return the new data to the user.  The same results can be "
      "achieved using the proxy and the redirect module.  With "
      "caching. This module is therefore quite obsolete, really.  But "
      "since it is so small, I have left it here. ";
constant module_unique = 0;

#define CONN_REFUSED "\
HTTP/1.0 503 Service Unavailable\r\n\
Content-type: text/html\r\n\
\r\n\
<title>Service unavailable</title>\
\
<h1 align=center>Service unavailable</h1>\
<hr noshade>\
<font size=+2>Please try again later.</font>\
<i>Sorry</i>\
<hr noshade>"

/* Simply relay a request to another server if the data was not found. */

void create()
{
  defvar("pri", "Last", "Module priority", TYPE_STRING_LIST,
	 "If last, first try to find the file in a normal way, otherways, "
	 "first try redirection.",
	 ({ "Last", "First" }));

  defvar("relayh", "", "Relay host", TYPE_STRING,
	 "The ip-number of the host to relay to");

  defvar("relayp", 80, "Relay port", TYPE_INT,
	 "The port-number of the host to relay to");
  
  defvar("always", "", "Always redirect", TYPE_TEXT_FIELD,
	 "Always relay these, even if the URL match the 'Don't-list'.");

  defvar("anti", "", "Don`t redirect", TYPE_TEXT_FIELD,
	 "Never relay these, unless the URL match the 'Always-list'.");
}

string comment()
{
  return "http://"+query("relayh")+":"+query("relayp")+"/";
}

void connected( object to, object from, object id )
{
  if(!id || !to || !to->query_address()) {
    if (id)
      id->end(CONN_REFUSED);
    if (to)
      destruct(to);
    return;
  }
  to->write(id->raw);
  id->do_not_disconnect = 0;
  caudium->shuffle( to, from );
}

array (string) always_list=({ });

array (string) anti_list = ({ });

void start()
{
  always_list=(QUERY(always)-"\r")/"\n";
  anti_list=(QUERY(anti)-"\r")/"\n";
}

int is_in_anti_list(string s)
{
  int i;
  for(i=0; i<sizeof(anti_list); i++) 
    if(glob(anti_list[i], s))  return 1;
}

int is_in_always_list(string s)
{
  int i;
  for(i=0; i<sizeof(always_list); i++) 
    if(glob(always_list[i], s)) return 1;
}

mapping relay(object fid)
{
  if(!is_in_always_list(fid["not_query"]) &&
     is_in_anti_list(fid["not_query"]))
    return 0;
  
  fid -> do_not_disconnect = 1;
  
  async_connect(QUERY(relayh), QUERY(relayp), connected, fid->my_fd, fid );
  return http_pipe_in_progress();
}

mapping last_resort(object fid)
{
  if(QUERY(pri) != "Last")  return 0;
  fid->misc->cacheable = 0;
  return relay(fid);
}

mapping first_try(object fid)
{
  if(QUERY(pri) == "Last") return 0;
  fid->misc->cacheable = 0;
  return relay(fid);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: pri
//! If last, first try to find the file in a normal way, otherways, first try redirection.
//!  type: TYPE_STRING_LIST
//!  name: Module priority
//
//! defvar: relayh
//! The ip-number of the host to relay to
//!  type: TYPE_STRING
//!  name: Relay host
//
//! defvar: relayp
//! The port-number of the host to relay to
//!  type: TYPE_INT
//!  name: Relay port
//
//! defvar: always
//! Always relay these, even if the URL match the 'Don't-list'.
//!  type: TYPE_TEXT_FIELD
//!  name: Always redirect
//
//! defvar: anti
//! Never relay these, unless the URL match the 'Always-list'.
//!  type: TYPE_TEXT_FIELD
//!  name: Don`t redirect
//
