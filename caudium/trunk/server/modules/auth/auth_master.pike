/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002 The Caudium Group
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
//!  have at least one authentication provider enabled.
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

//
//
//  beginning of module support functions
//
//

constant module_type = MODULE_AUTH;
constant module_name = "Master authentication and security";
constant module_doc  = "This module handles the security in roxen, and uses "
	"sub-modules to communicate with authenticators and user databases "
        "such as passwd or NIS. It also maintains the user database "
	" for all other modules in Caudium, e.g. the user homepage module."
	"<p><b>Remember:</b> by itself, this module knows nothing about "
	" users. You must have at least one authentication provider enabled.";

constant module_unique = 1;

object mapcache,usercache,groupcache;

void create()
{
  defvar("cachetimeout", 300, "Cache Timeout", TYPE_INT, 
    "Number of seconds a cached user or group entry should be kept."
  );
}

void start(object conf)
{
  // first, set up the map, group and user caches.
  setup_cache(conf);
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

//
//
// end of module support functions
//
//

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
   if(!user && !password) return 0;
   mixed data=get_user_info(user);

   if(!data) return 0; // user doesn't exist.
   if(data["__authdata"] && 
        (data["__authdata"] == 
	  Crypto.string_to_hex(
            Crypto.md5()->update(user+"|"+password)->digest())
        )
     )
     return 1;  // password matches previous cached success.

   int auth=low_authenticate(user, password);

   if(!auth) return 0; // authentication failed.
   data["__authdata"]=Crypto.string_to_hex(
         Crypto.md5()->update(user+"|"+password)->digest());
   set_user_info(user, data);
   return 1; // success!
}

//! given a username, find a numeric user id.
//! @param username
//! the string user name to look for
//! @returns
//! numeric user id or -1 if user is not found.
int get_uid(string username)
{
   if(!username) return 0;
   mapping data=get_user_info(username);
   if(!data) return -1; // user doesn't exist.
   else return data->uid;
}

//! given a groupname, find a numeric group id.
//! @param groupname
//! the string group name to look for
//! @returns
//! numeric group id or -1 if group is not found. (should we just assume
//! that gid 0 doesn't exist?)
int get_gid(string groupname)
{
}

//! given a numeric user id, find a user name.
//! @param uid
//! the numeric user id to look for
//! @returns
//! username or 0 if not found.
string|int get_username(int uid)
{
}

//! given a numeric group id, find a group name.
//! @param gid
//! the numeric group id to look for
//! @returns
//! group name or 0 if not found.
string|int get_groupname(int gid)
{
}

//! find information about a user.
//! @param user
//! user name
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
{
}

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
{
}

//! listing of known users
//! @returns
//! array containing known user names, zero if none exist.
array|int list_all_users()
{
}

//! listing of known groups
//! @returns
//! array containing known group names, zero if none exist.
array|int list_all_groups()
{
}

//! return an array of information for a user
//! @param u
//! user name to return data for
//! @returns
//! @array
//!   @elem string 0
//!     user name
//!   @elem string 1
//!     password
//!   @elem int 2
//!     numeric user id
//!   @elem int 3
//!     numeric group id (primary)
//!   @elem string 4
//!     real name (gecos)
//!   @elem string 5
//!     home directory
//!   @elem string 6
//!     login shell
//! @endarray
array(string) userinfo(string u) 
{
  return ({});
}

//! find information about a user from numeric userid
//! @param u
//!   numeric user id
//! @returns 
//!   a string containing user name
string user_from_uid(int u)
{
   return "";
}


//! authenticate a user
//! @param auth
//!   @array
//!     @elem 0 string
//!        valid value is "Basic" for basic authentication
//!     @elem 1 string
//!        string containing user name and password, separated by a colon (:). 
//!   @endarray
//! @returns
//!   @array
//!     @elem 0 int
//!      1 on success, 0 on failure
//!     @elem 1 string
//!      user name
//!     @elem 2 int|string
//!      0 for successful authentication, otherwise the invalid password.
//!   @endarray
array|int auth(array(string) auth, object id)
{
  return ({});
}

//
//
// end of public "user" functions
//
//

int succ, fail, nouser;

mapping failed  = ([ ]);

void setup_cache(object conf)
{
  mapcache=caudium->cache_manager->get_cache(
	conf->query("MyWorldLocation")+"-auth_mapcache");
  usercache=caudium->cache_manager->get_cache(
	conf->query("MyWorldLocation")+"-auth_usercache");
  groupcache=caudium->cache_manager->get_cache(
	conf->query("MyWorldLocation")+"-auth_groupcache");
}

int low_authenticate(string user, string password)
{
  int res=caudium->call_provider("authentication", authenticate, user, password);
  return res;
}

mapping get_user_info(string username)
{
  mapping data=usercache->retreive(username, low_get_user_info, username);
  return data;
}

int low_get_user_info(string username)
{
  mapping data=caudium->call_provider("authentication", get_user_info, username);
  int i=set_user_info(username, data);
  return i;
}

int set_user_info(string username, mapping data)
{
  usercache->cache_pike(username, data, QUERY("cachetimeout"));
  return 1;
}
