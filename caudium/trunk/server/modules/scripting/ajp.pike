/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

/* Standard includes */

#include <module.h>
inherit "module";
inherit "caudiumlib";

#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)


constant cvs_version = "$Id$";

constant thread_safe=1;
constant module_type = MODULE_LOCATION;
constant module_name = "AJP | Tomcat 4 Connector";
constant module_doc  =
#"This module allows you to connect to a Tomcat 4 servlet container
 using AJP 1.3. This module is the equivalent of mod_jk";

constant module_unique = 0;

void create () {
    defvar( "mountpoint", "/", "Filesystem mountpoint", TYPE_STRING,
	    "This is the location in the virtual file system where this "
	    "module will be mounted." );
    defvar("server", "localhost", "Container Host", TYPE_STRING,
            "This is the hostname or ip address for your Tomcat host");
    defvar("port", 8009, "Container Port", TYPE_INT,
            "This is the port number Tomcat is listening on");
}

object client;

void start (int cnt, object conf) {
  if(QUERY(server) && strlen(QUERY(server)) && QUERY(port))
    client=Protocols.AJP.client(QUERY(server), QUERY(port), 2);
}

string query_location () {
  return QUERY(mountpoint);
}

mixed find_file ( string path, object id )
{
  if(!client)
    return "ERROR: AJP Connector not configured.";
  mapping res= client->handle_request(id);
  mapping ret=([]);  
  ret->error= res->response_code;
  if(res->body)
  {
    ret->data=res->body;
    ret->len=strlen(res->body);
  }
  if(res->response_msg && res->response_msg!="")
    ret->rettext=res->response_msg;

  ret->extra_heads=res->response_headers;

  return ret;
}

void|array find_dir ( string path, object id ) {
}


void|string real_file ( string path, object id ) {
    return 0;
}

string query_name()
{
  return sprintf("mounted on <i>%s</i>",
		 query("mountpoint"));
}

