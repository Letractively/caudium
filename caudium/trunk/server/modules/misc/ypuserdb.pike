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

/*
 * YP User database. Reads the system password database and use it to
 * authentificate users.
 */

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_AUTH;
constant module_name = "YP (NIS) authorization";
constant module_doc  = "Experimental module for authorization using "
	      "Pike's internal YP-database interface.";
constant module_unique = 1;

#ifndef __NT__
#if constant(Yp.Domain)

// import Stdio;
// import Array;
// import Yp;

/*
 * Globals
 */
object(Yp.Domain) domain;

/*
 * Statistics
 */

int succ, fail, nouser, emptypasswd;
mapping(string:int) failed = ([]);

string status()
{
  return("<h1>Security info</h1>\n"
	 "<b>YP-server:</b> " + domain->server("passwd.byname") + "<br>\n"
	 "<b>YP-domain:</b> " + default_yp_domain() + "<br>\n"
	 "<p>\n"
	 "<b>Successful auths:</b> " + (string)succ +
	 ", " + (string)emptypasswd + " had empty password fields.<br>\n"
	 "<b>Failed auths:</b> " + (string)fail +
	 ", " + (string)nouser + " had the wrong username.<br>\n"
	 "<p>\n"
	 "<h3>Failure by host</h3>" +
	 (Array.map(indices(failed), lambda(string s) {
	   return caudium->quick_ip_to_host(s) + ": " + failed[s] + "<br>\n";
	 }) * "") +
	 "<p>The database has " + sizeof(domain->all("passwd.byname")) +
	 " entries.");
}

/*
 * Auth functions
 */

array(string) userinfo(string u)
{
  if (sizeof(u)) {
    string s = domain->match("passwd.byname", u);
    if (s) {
      return(s/":");
    }
  }
  return(0);
}

array(string) userlist()
{
  mapping(string:string) m = domain->all("passwd.byname");
  if (m) {
    return(indices(m));
  }
  return(0);
}

string user_from_uid(int u)
{
  string s = domain->match("passwd.byuid", (string)u);
  if (s) {
    return((s/":")[0]);
  }
  return(0);
}

array|int auth(array(string) auth, object id)
{
  array(string) arr = auth[1]/":";
  string u, p;

  u = arr[0];
  if (sizeof(arr) <= 1) {
    p = "";
  } else {
    p = arr[1..]*":";
  }
  string s = domain->match("passwd.byname", u);
  if (!s) {
    fail++;
    nouser++;
    failed[id->remoteaddr]++;
    return(({ 0, auth[1], -1 }));
  }
  arr = s/":";
  if ((!sizeof(arr[1])) || crypt(p, arr[1])) {
    // Valid user
    id->misc->uid = arr[2];
    id->misc->gid = arr[3];
    id->misc->gecos = arr[4];
    id->misc->home = arr[5];
    id->misc->shell = arr[6];
    succ++;
    emptypasswd += !sizeof(arr[1]);
    return(({ 1, u, 0 }));
  }
  fail++;
  failed[id->remoteaddr]++;
  return(({ 0, auth[1], -1 }));
}

/*
 * Registration and initialization
 */

void start(int i)
{
  if (!domain) 
    domain = Yp.Domain();
}

#endif /* constant(Yp.Domain) */
#endif
