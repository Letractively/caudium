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
static private string host, path;

static private object rpc;

static private void disconnect()
{
  rpc = 0;
}

static private void establish()
{
  int rpc_port;
  object o = Stdio.File();
  signal(signum("SIGALRM"), lambda() { throw("timeout"); });
  alarm(5);
  o->connect(host, port);
  o->write(sprintf("GET %s\r\n", "/"+combine_path(path, "rpc/")));
  sscanf(o->read(), "port %d", rpc_port);
  rpc = RoxenRPC.Client(host, rpc_port, "Q");
  signal(signum("SIGALRM"), lambda() {});
  alarm(time());
}

mixed `->(string var)
{
  if(!rpc) establish();
  remove_call_out(disconnect);
  call_out(disconnect, 60);
  mixed v;
  if(catch(v = predef::`->(rpc,var))) {
    establish();
    v = predef::`->(rpc,var);
  }
  return v;
}

void create(string url)
{
  if(url[-1] == '/')
    url = url[0..(sizeof(url)-2)];
  
  sscanf(url-"http://", "%s:%d/%s", host, port, path);
  if(!port)
    port = 80;
  if(!path)
    path = "";
}

