/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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
object proxy;
constant thread_safe = 1;
constant cvs_version = "$Id$";

array register_module()
{
  return ({0,"Upgrade Server Proxy",
	     ("<b>Proxies</b> the Upgrade Server Protocol. This is not an "
	      "actual upgrade server.") });
}

class Proxy
{
  object server, client;
  string ch, cp;

  void close_client()
  {
    if(client) destruct(client);
  }
  
  void `->(string ident)
  {
    remove_call_out(close_client);
    call_out(close_client, 20);
    if(!client) client = RoxenRPC.Client(ch,(int)cp,"upgrade");
    return predef::`->(client, ident);
  }
  
  void create(int port, string master)
  {
    server = RoxenRPC.Server(0, port);
    sscanf(master, "%s:%s", ch, cp);
    server->provide("upgrade", this_object());
  }
}

void start()
{
  if(proxy) proxy->close_client();
  proxy = Proxy(query("port"), query("master"));
}

void create()
{
  defvar("port", 55875, "Proxy Port", TYPE_INT,  "The port to bind to");
  defvar("master", "skuld.idonex.se:23", "Upgrade server master", TYPE_STRING,
	 "The server to connect to");
}
