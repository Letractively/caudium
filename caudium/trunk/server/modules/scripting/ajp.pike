/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2003 The Caudium Group
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
constant module_type = MODULE_FILE_EXTENSION|MODULE_LOCATION;
constant module_name = "AJP | Tomcat 4 Connector";
constant module_doc  =
#"This module allows you to connect to a Tomcat 4 servlet container
 using AJP 1.3. This module is the equivalent of mod_jk";

constant module_unique = 0;

void create () {
  defvar("ex", 0, "File extension connector", TYPE_FLAG,
         "Use a servlet mapping based on file extension rather than "
         "path location.");
  defvar("ext", ({}), "Handle extensions", TYPE_STRING_LIST,
         "All files ending with these extensions, will be handled by "+
         "this connector.", 0,
         lambda() { return !query("ex"); });
    defvar( "mountpoint", "/ajp/NONE", "Filesystem mountpoint", TYPE_STRING,
	    "This is the location in the virtual file system where this "
	    "module will be mounted.",0, lambda() {return query("ex");} );
    defvar("rxml", 1, "Parse output?", TYPE_FLAG,
            "If set to yes, html output will be RXML-parsed.");
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

mixed handle_file_extension(object o, string e, object id)
{
  if(!client)
    return "ERROR: AJP Connector not configured.";
  mapping res= client->handle_request(id);
  mapping ret=([]);  
  ret->error= res->response_code;

  if(res->body)
  {
    if(QUERY(rxml) && res->response_headers["Content-Type"] 
     && ((((res->response_headers["Content-Type"])/";")[0])=="text/html"))
        ret->data=parse_rxml(res->body, id);
     else
        ret->data=res->body;

    ret->len=strlen(ret->data);
  }
  if(res->response_msg && res->response_msg!="")
    ret->rettext=res->response_msg;

  ret->extra_heads=res->response_headers;

  return ret;
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
    if(QUERY(rxml) && res->response_headers["Content-Type"] 
     && ((((res->response_headers["Content-Type"])/";")[0])=="text/html"))
        ret->data=parse_rxml(res->body, id);
     else
        ret->data=res->body;

    ret->len=strlen(ret->data);
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
  if(query("ex"))
    return sprintf("Server %s:%d handling extension %s",
                   query("server"), 
                   query("port"),
                   query("ext")*", ");

  else return sprintf("%s:%d mounted on <i>%s</i>",
		 query("server"),
		 query("port"),
		 query("mountpoint"));
}

array(string) query_file_extensions()
{
  return (query("ex")? QUERY(ext) : ({}));
}

string query_location () {
  return query("ex") ? "NONE/" : QUERY(mountpoint);
}


