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
//! module: Master authentication and user database
//!  This module handles the security in Caudium, and uses
//!  sub modules to communicate with authentication and user databases,
//!  such as passwd or NIS. It also maintains the user database for all other
//!  modules in Caudium, e.g. the user homepage module.
//!  Remember: by itself, this module knows nothing about users. You must
//!  have at least one authentication submodule enabled.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_AUTH
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";

#include <module.h>
inherit "module";
inherit "cachelib";
inherit "caudiumlib";

constant module_type = MODULE_AUTH;
constant module_name = "Master authentication and security";
constant module_doc  = "This module handles the security in roxen, and uses "
	"sub-modules to communicate with authenticators and user databases "
        "such as passwd or NIS. It also maintains the user database "
	" for all other modules in Caudium, e.g. the user homepage module."
	"<p><b>Remember:</b> by itself, this module knows nothing about "
	" users. You must have at least one authentication submodule enabled.";

constant module_unique = 1;

object usercache,groupcache;


//
// 
// Public functions
//
//

//! authenticate a user.
//! @param user
//! the username to authenticate against
//! @param password
//! the password for user
//! @returns
//! 1 for successful authentication, 0 for failure
int authenticate(string user, string password)
{
}

//! given a username, find a numeric user id.
//! @param username
//! the string user name to look for
//! @returns
//! numeric user id or -1 if user is not found.
int get_uid(string username)

//! given a groupname, find a numeric group id.
//! @param groupname
//! the string group name to look for
//! @returns
//! numeric group id or -1 if group is not found. (should we just assume
//! that gid 0 doesn't exist?)
int get_gid(string groupname)

//! given a numeric user id, find a user name.
//! @param uid
//! the numeric user id to look for
//! @returns
//! username or 0 if not found.
string|int get_username(int uid)

//! given a numeric group id, find a group name.
//! @param gid
//! the numeric group id to look for
//! @returns
//! group name or 0 if not found.
string|int get_groupname(int gid)

//! find information about a user.
//! @returns
//! a mapping containing user information, which may vary depending
//! on the user database source. At a minimum, the result will contain
//! the following elements:
//! @mapping
//! @member string "username"
//! user name
//! @member int "uid"
//! numeric user id
//! @member string "description"
//! long user description
//! @member array(string)|int "groups"
//  group memberships or 0 if none
//! @endmapping
mapping|int user_info(string username)

//! find information about a group.
//! @returns
//! a mapping containing group information, which may vary depending
//! on the user database source. At a minimum, the result will contain
//! the following elements:
//! @mapping
//! @member string "groupname"
//! group name
//! @member int "gid"
//! numeric group id
//! @member string "description"
//! long group description, if any
//! @member array(string)|int "users"
//!  members of group or 0 if none
//! @endmapping
mapping|int group_info(string groupname)

//! listing of known users
//! @returns
//! array containing known user names, zero if none exist.
array|int list_all_users()

//! listing of known groups
//! @returns
//! array containing known group names, zero if none exist.
array|int list_all_groups()

array(string) userinfo(string u) 
{
  if(!users[u])
    try_find_user(u);
  return users[u];
}

void create()
{

}

void start(object conf)
{
  // first, set up the group and user caches.
  setup_cache();
}

int succ, fail, nouser;

mapping failed  = ([ ]);

array|int auth(array(string) auth, object id)
{
  string u, p;
  array(string) arr = auth[1]/":";

  if (sizeof(arr) < 2) {
    return ({ 0, auth[1], -1 });
  }

  u = arr[0];
  p = arr[1..]*":";

  if(QUERY(method) == "none")
  {
    succ++;
    return ({ 1, u, 0 });
  }

  read_data_if_not_current();

  if(!users[u] || !(stringp(users[u][1]) && strlen(users[u][1]) > 6))
  {
    nouser++;
    fail++;
    failed[id->remoteaddr]++;
    return ({0, u, p}); 
  }
  
  if(!users[u][1] || !crypt(p, users[u][1]))
  {
    fail++;
    failed[id->remoteaddr]++;
    caudium->quick_ip_to_host(id->remoteaddr);
    return ({ 0, u, p }); 
  }
  id->misc->uid = users[u][2];
  id->misc->gid = users[u][3];
  id->misc->gecos = users[u][4];
  id->misc->home = users[u][5];
  id->misc->shell = users[u][6];
  succ++;
  return ({ 1, u, 0 }); // u is a valid user.
}

string status()
{
  return 
    ("<h1>Security info</h1>"+
     "<b>Successful auths:</b> "+(string)succ+"<br>\n" + 
     "<b>Failed auths:</b> "+(string)fail
     +", "+(string)nouser+" had the wrong username<br>\n"
     + "<h3>Failure by host</h3>" +
     Array.map(indices(failed), lambda(string s) {
       return caudium->quick_ip_to_host(s) + ": "+failed[s]+"<br>\n";
     }) * "" 
);
}

setup_cache(object conf)
{
  usercache=caudium->cache_manager->get_cache(
	conf->query("MyWorldLocation")+"-usercache");
  groupcache=caudium->cache_manager->get_cache(
	conf->query("MyWorldLocation")+"-groupcache");
}

