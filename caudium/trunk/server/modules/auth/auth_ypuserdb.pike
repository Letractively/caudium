/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

/*
 * YP User database. Reads the system password database and use it to
 * authenticate users.
 */

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "Authentication Provider: NIS";
constant module_doc  = "Experimental module for authorization using "
	      "Network Information Service (NIS).";
constant module_unique = 1;

#if constant(Yp.Domain)

/*
 * Globals
 */
object domain;
mapping usergroups=([]);

/*
 * Statistics
 */

int succ, fail, nouser, emptypasswd;

string status()
{
  return("<h1>Security info</h1>\n"
	 "<b>YP-server:</b> " + domain->server("passwd.byname") + "<br>\n"
	 "<b>YP-domain:</b> " + Yp.default_domain() + "<br>\n"
	 "<p>\n"
	 "<b>Successful auths:</b> " + (string)succ +
	 ", " + (string)emptypasswd + " had empty password fields.<br>\n"
	 "<b>Failed auths:</b> " + (string)fail +
	 ", " + (string)nouser + " had the wrong username.<br>\n"
	 "<p>\n"
	 "<p>The database has " + sizeof(domain->all("passwd.byname")) +
	 " entries.");
}

/*
 * Auth functions
 */

mapping|int get_user_info(string u)
{
  if (sizeof(u)) {
    string s = domain->match("passwd.byname", u);
    if (s) {
      array ud=s/":";
      return(["username": ud[0], 
	"primary_group": get_groupname(ud[3]),
	"name": ud[4],
	"uid": ud[2],
	"home_directory": ud[5],
	"login_shell": ud[6],
	"groups": get_groups_for_user(ud[0]),
	"_source": query("_name")
	]);
    }
  }
  return(0);
}


mapping|int get_group_info(string g)
{
  if (sizeof(g)) {
    string s = domain->match("group.byname", g);
    if (s) {
      array gd=s/":";
      return(["groupname": gd[0], 
	"gid": gd[2],
	"users":  ((gd[4] && gd[4]!="")?((gd[4]/",")-({""})):({})),
	"_source": query("_name")
	]);
    }
  }
  return(0);
}

array get_groups_for_user(string user)
{
  if(usergroups[user]) return usergroups[user];

  return ({});
}

array(string) list_all_users()
{
  mapping(string:string) m = domain->all("passwd.byname");
  if (m) {
    return(indices(m));
  }
  return(0);
}

array(string) list_all_groups()
{
  mapping(string:string) m = domain->all("group.byname");
  if (m) {
    return(indices(m));
  }
  return(0);
}

string|int get_username(int|string uid)
{
  string s = domain->match("passwd.byuid", (string)uid);
  if (s) {
    return((s/":")[0]);
  }
  return(0);
}

string|int get_groupname(int|string gid)
{
  string s = domain->match("group.bygid", (string)gid);
  if (s) {
    return((s/":")[0]);
  }
  return(0);
}

int authenticate(string user, string password)
{
  string s = domain->match("passwd.byname", user);
  if (!s) {
    fail++;
    nouser++;
    return 0;
  }
  array arr = s/":";
  if ((!sizeof(arr[1])) || crypt(password, arr[1])) {
    succ++;
    emptypasswd += !sizeof(arr[1]);
    return 1;
  }
  fail++;
  return -1;
}

void update_usergroups()
{
  usergroups=([]); // clear the map.

  mapping(string:string) m = domain->all("group.byname");
  foreach(indices(m), string g)
  {
    array gd=(m[g]/":");
    array gu=({});
    if(gd[4]) gu=gd[4]/",";

    foreach(gu, string user)
      if(usergroups[user])
        usergroups[user]+=({g});
      else
        usergroups[user]=({g});
  }
  
  call_out(update_usergroups, query("update"));
}

/*
 * Registration and initialization
 */

void start(int i)
{
  if (!domain) 
    domain = Yp.Domain();
  update_usergroups();
 
}

string query_provides()
{
  return "authentication";
}

void create()
{
defvar("update", 60,
         "Interval between automatic updates of the user database",
         TYPE_INT|VAR_MORE,
         "This specifies the interval in minutes between automatic updates "
         "of the user/group database.");

}
#endif /* constant(Yp.Domain) */

