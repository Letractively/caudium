/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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
// $Id$
//
// Roxen HTTP RPC
//


static private int port;
static private string host;

static private object rpc;
static private function security;

mapping http(string path)
{
  if(path == "rpc/")
    return ([ "raw":1, "data":"port "+port ]);
}

static private int ip_security(string ip)
{
  ip = (ip/" ")[0];
  array a = gethostbyaddr(ip) || ({ ip });
  return search(Array.map(({ a[0] }) + a[1] + a[2], security),1)+1;
}

void create(object o, function|void security_in)
{
  rpc = RoxenRPC.Server(0, 0);
  if(security = security_in)
    rpc->set_ip_security(ip_security);
  rpc->provide("Q", o);
  
  string adr = rpc->query_address();
  host = (adr/" ")[0];
  port = (int) (adr/" ")[1];
}
