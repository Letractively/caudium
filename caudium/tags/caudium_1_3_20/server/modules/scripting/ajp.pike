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

#define DEFAULT_PORT 8009 

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
    defvar("hosts", "localhost:8009", "Container Host", TYPE_TEXT_FIELD,
            "This is the hostname or ip address and port for your Tomcat host, formatted as host:port."
            "Multiple hosts may be used for load balancing by placing one entry on each line.");
}

array ajp_hosts;
mapping clients;
object module_cache;

void start (int cnt, object conf) {
  ajp_hosts=({});
  clients=([]);

  module_cache=GET_CACHE();
  if(QUERY(hosts) && QUERY(hosts)!="")
  {
     array r=QUERY(hosts)/"\n";
     foreach(r, string h)
     {
        if(!h || h=="") continue;
        array hp=h/":";
        if(sizeof(hp)==2)
          ajp_hosts+=({ ({hp[0], (int)(hp[1]), hp[0]+hp[1]}) });
        else
          ajp_hosts+=({ ({hp[0], DEFAULT_PORT, hp[0]+DEFAULT_PORT}) });
     }
  }

}

int decode_session(string session)
{
   int value = 0;
   int i;

   for (i = 2; i >= 0; i--) {
     int code = session[i];

     if (code >= 'a' && code <= 'z')
       value = 64 * value + code - 'a';
     else if (code >= 'A' && code <= 'Z')
       value = 64 * value + code - 'A' + 26;
     else if (code >= '0' && code <= '9')
       value = 64 * value + code - 'A' + 52;
     else if (code == '_')
       value = 64 * value + 62;
     else if (code == '/')
       value = 64 * value + 63;
     else
       return -1;
     }

   if (i > -1)
     return -1;
   else
     return value;
}


mixed handle_file_extension(object o, string e, object id)
{
  return handle_request(id);
}

mixed handle_request(object id)
{
  string jsid, shost, sident;
  int sport;
  array r;
  mixed err;

  if(!ajp_hosts)
    return "ERROR: AJP Connector not configured.";
 
#ifdef AJP_DEBUG
  werror("size of clients: " + sizeof(clients) + "\n");
#endif

  // get jsessionid from request - this is needed to determine
  // which ajp host to use
  if (id->cookies->JSESSIONID) jsid = id->cookies->JSESSIONID;
  if (id->misc->jspquery) sscanf(id->misc->jspquery, "jsessionid=%s", jsid);

  if(jsid)  // we have an existing session, which resin do we connect to?
  {
     r=module_cache->retrieve(jsid);
  }

 if(!jsid || !r) // we don't know the current session's destination, so pick one.
  {
    r=ajp_hosts[random(sizeof(ajp_hosts))];
  }

  shost=r[0];
  sport=r[1];
  sident=r[2];

  if(!clients || !clients[sident] || !objectp(clients[sident]))
  {
    clients[sident]=Protocols.AJP.client(shost, sport, 2);
#ifdef AJP_DEBUG
    werror("clients[" + sident+ "]=Protocols.AJP.client(" + shost+ ", " + sport +" , 2);\n");
#endif
  }
  err=catch(mapping res= clients[sident]->handle_request(id));
  if(err)
  {
     int ok=0;
     foreach(ajp_hosts, array host)
     {
       err=catch 
       {
         shost=host[0];
         sport=host[1];
         sident=host[2];
         if(!clients[sident] || !objectp(clients[sident]))
         {
           clients[sident]=Protocols.AJP.client(shost, sport, 2);
#ifdef AJP_DEBUG
           werror("clients[" + sident+ "]=Protocols.AJP.client(" + shost+ ", " + sport +" , 2);\n");
#endif
         }
         res=clients[sident]->handle_request(id);
       };
       // if there's an error, remove the client and try another one.
       if(err) 
       {
          m_delete(clients, sident); 
          continue; 
       }
       else 
       { 
          ok=1; 
          break; 
       }
     }

    if(!ok) return "ERROR: Unable to connect to an AJP host.";
       
  }

  // if we have a session, let us remember the host we conneted to.
  if(jsid)
   module_cache->store(cache_pike(({ shost, sport, sident }), jsid, 3600));

  // set sessionid
  if (jsid) id->misc->ajpsession = decode_session(jsid);

  // done with the load balancing stuff.

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
    ret->rettext=ret->error + " " + res->response_msg;

  ret->extra_heads=res->response_headers;

// werror("result:" + sprintf("%O", ret) + "\n");
  return ret;
}

mixed find_file ( string path, object id )
{
  return handle_request(id);
}

void|array find_dir ( string path, object id ) {
}


void|string real_file ( string path, object id ) {
    return 0;
}

// jsp has own query string standard - all after ";" is jsp query
int|mapping last_resort(object id)
{
  string toparse = id->not_query;
  array(string) tmp;

  tmp = toparse / ";";

  // don't parse, if id->misc->jspquery exists
  if (id->misc->jspquery) return 0;

  // there is no jsp query
  if (sizeof(tmp) == 1) return 0;

  // assign all after ";" to id->misc->jspquery
  id->not_query = tmp[0];
  id->misc->jspquery = tmp[1..] * ";";
  return 1;
}

string query_name()
{
  if(query("ex"))
    return sprintf("Server(s) %s handling extension %s",
                   (query("hosts")/"\n")*" ,", 
                   query("port"),
                   query("ext")*", ");

  else return sprintf("%s mounted on <i>%s</i>",
		 (query("hosts")/"\n")*" ,",
		 query("mountpoint"));
}

array(string) query_file_extensions()
{
  return (query("ex")? QUERY(ext) : ({}));
}

string query_location () {
  return query("ex") ? "NONE/" : QUERY(mountpoint);
}



/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: ex
//! Use a servlet mapping based on file extension rather than path location.
//!  type: TYPE_FLAG
//!  name: File extension connector
//
//! defvar: ext
//! All files ending with these extensions, will be handled by 
//!  type: TYPE_STRING_LIST
//!  name: Handle extensions
//
//! defvar: mountpoint
//! This is the location in the virtual file system where this module will be mounted.
//!  type: TYPE_STRING
//!  name: Filesystem mountpoint
//
//! defvar: rxml
//! If set to yes, html output will be RXML-parsed.
//!  type: TYPE_FLAG
//!  name: Parse output?
//
//! defvar: server
//! This is the hostname or ip address for your Tomcat host
//!  type: TYPE_STRING
//!  name: Container Host
//
//! defvar: port
//! This is the port number Tomcat is listening on
//!  type: TYPE_INT
//!  name: Container Port
//
