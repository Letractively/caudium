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

#define DEBUG 1

#ifdef DEBUG
#define ERROR(X) werror("AuthMaster: " + X + "\n");
#else
#define ERROR(X)
#endif

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

int timeout, listtimeout =300; // keep for 5 minutes
object cache;

void create()
{
  defvar("cachetimeout", 300, "Cache Timeout", TYPE_INT, 
    "Number of seconds a cached user or group entry should be kept."
  );
  defvar("listcachetimeout", 3600, "List Cache Timeout", TYPE_INT, 
    "Number of seconds a full user or group list should be kept."
  );
}

void start(int level, object conf)
{
  // first, set up the map, group and user caches.

  if(conf)
  {
    setup_cache(conf);
    int timeout=query("cachetimeout");
    int listtimeout=query("listcachetimeout");
  }
}

string status()
{
  string h="";

  foreach(my_configuration()->get_providers("authentication"),object o)
    h+=sprintf("%s (%s)", o->module_name, o->query("_name"));

  return 
    ("<h1>Security info</h1>"+
     "<b>Registered Auth Handlers:</b> " + h + "<br>\n"
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
   if(!user && !password) { fail++; nouser++; return 0; }
   mixed data=get_user_info(user);
   if(!data)
   {
     ERROR("user " + user + " doesn't exist.\n");
     fail++;
     nouser++;
     return 0; // user doesn't exist.
   }
   if(data["__authdata"] && 
        (data["__authdata"] == Caudium.Crypto.hash_md5(user+"|"+password, 1))
        )
     )
     {
       succ++;
       return 1;  // password matches previous cached success.
     }
   int auth=low_authenticate(user, password);
   if(!auth) {fail++; return 0; } // authentication failed, user doesn't exist.
   if(auth==-1) {fail++; return 0; } // authentication failed, exists.
   data["__authdata"]=Caudium.Crypto.hash_md5(user+"|"+password);
   set_user_info(user, data);
   succ++;
   return 1; // success!
}

//! given a username, find a numeric user id.
//! @param username
//! the string user name to look for
//! @returns
//! numeric user id or -1 if user is not found.
int get_uid(string username)
{
   if(!username) return -1;
   mapping data=get_user_info(username);
   if(!data) return -1; // user doesn't exist.
   else if(data->uid=="") return -1;
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
   if(!groupname) return -1;
   mapping data=get_group_info(groupname);
   if(!data) return -1; // group doesn't exist.
   else if(data->gid=="") return -1;
   else return data->gid;
}

//! given a numeric user id, find a user name.
//! @param uid
//! the numeric user id to look for
//! @returns
//! username or 0 if not found.
string|int get_username(int uid)
{
  int|string data=cache->retrieve("uid-" + uid, low_get_username, ({uid}));
  if(data==-1) return 0;
  else return data;   
}

//! given a numeric group id, find a group name.
//! @param gid
//! the numeric group id to look for
//! @returns
//! group name or 0 if not found.
string|int get_groupname(int gid)
{
  int|string data=cache->retrieve("gid-" + gid, low_get_groupname, ({gid}));
  if(data==-1) return 0;
  else return data;
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
//! @member string "name"
//! long user description
//! @member multiset(string) "groups"
//! group memberships
//! @member string "shell"
//! login shell (optional)
//! @member string "home_directory"
//! home directory (optional)
//! @member string "email"
//! email address (optional)
//! @endmapping
mapping|int user_info(string username)
{
   if(!username) return 0;
   else 
   {
      mapping|int i=get_user_info(username);
      if(!i) 
        return i;
      else 
      {
         mapping c=copy_value(i);
         m_delete(c, "__authdata");
         return c;
      }
   }
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
//! @member string "name"
//! long group description, if any
//! @member multiset(string) "users"
//!  members of group
//! @endmapping
mapping|int group_info(string groupname)
{
   if(!groupname) return 0;
   else 
   {
      mapping|int i=get_group_info(groupname);
      return i;
   }
}

//! listing of known users
//! @returns
//! array containing known user names, zero if none exist.
array|int list_all_users()
{
  array data=cache->retrieve("userlist", low_list_all_users, ({}));
  return data;
}

//! listing of known groups
//! @returns
//! array containing known group names, zero if none exist.
array|int list_all_groups()
{
  array data=cache->retrieve("grouplist", low_list_all_groups, ({}));
  return data;
}

//! return an array of information for a user
//!
//! @deprecated
//!
//! @param u
//! user name to return data for
//! @returns
//! @array
//!   @elem string
//!     user name
//!   @elem string 
//!     password (will always be empty)
//!   @elem int 
//!     numeric user id
//!   @elem int 
//!     numeric group id (primary)
//!   @elem string 
//!     real name (gecos)
//!   @elem string 
//!     home directory
//!   @elem string 
//!     login shell
//! @endarray
array(string) userinfo(string u) 
{
  report_warning("auth_module->userinfo() is deprecated and may not be available in future releases of this software.");
  if(!u || u=="") return 0;

  mapping data=get_user_info(u);
  if(!data) return 0;

  return ({ data->username, "", data->uid||"", 
		data->primary_gid||"", data->name||"", 
		data->home_directory||"", data->shell||""});
}

//! find information about a user from numeric userid
//! @param u
//!   numeric user id
//! @returns 
//!   a string containing user name
string user_from_uid(int u)
{
   return get_username(u);
}


//! authenticate a user
//!
//! @deprecated 
//!
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
  report_warning("auth_module->auth() is deprecated and may not be available in future releases of this software.");
  if(!auth || sizeof(auth) !=2) error("incorrect arguments to auth().");
  array a=auth[1]/":";
  if(sizeof(a)!=2) error("incorrectly formatted user/password string.");
  int res=authenticate(a[0], a[1]);
  if(res)
    return ({1, a[0], 0});
  else return ({0, a[0], a[1]});
}

//
//
// end of public "user" functions
//
//

int succ, fail, nouser;

mapping failed  = ([ ]);

private void setup_cache(object conf)
{
  if(!conf) return;

  cache=caudium->cache_manager->get_cache(
	conf->query("MyWorldLocation")+"-auth_cache");
}

private int low_authenticate(string user, string password)
{
  int res=my_configuration()->call_provider("authentication", "authenticate", user, password);
  ERROR("low_authenticate: " + res + "\n");
  return res;
}

private mapping|int get_user_info(string username)
{

  mapping|int data=cache->retrieve("user-" + username, low_get_user_info, ({username}));
  return data;
}

private mapping|int get_group_info(string groupname)
{
  mapping|int data=cache->retrieve("group-" + groupname, low_get_group_info, ({groupname}));
  return data;
}

private mapping|int low_get_user_info(string username)
{
  mapping data=my_configuration()->call_provider("authentication", "get_user_info", username);
  if(!data) return 0; // we won't set data for a non existant user.
  if(!(data->username && data->uid && 
    data->name && data->primary_group && data->groups))
  {
     ERROR("incomplete data for user " + username);
     return 0;
  }
  int i=set_user_info(username, data);
  return data;
}

private array low_list_all_users()
{
  array data=({});

  array m=my_configuration()->get_providers("authentication");

  foreach(m, object module)
    data+=module->list_all_users();

  int i=set_user_list(data);
  return data;
}

private array low_list_all_groups()
{
  array data=({});

  array m=my_configuration()->get_providers("authentication");

  foreach(m, object module)
    data+=module->list_all_groups();

  int i=set_group_list(data);
  return data;
}

private string|int low_get_username(int uid)
{
  string data=my_configuration()->call_provider("authentication", "get_username", uid);
  if(!data) return -1; // we won't set data for a non existant user.

  int i=set_username(uid, data);
  return data;
}

private string|int low_get_groupname(int gid)
{
  string data=my_configuration()->call_provider("authentication", "get_groupname", gid);
  if(!data) return -1; // we won't set data for a non existant user.

  int i=set_groupname(gid, data);
  return data;
}

private mapping|int low_get_group_info(string groupname)
{
  mapping data=my_configuration()->call_provider("authentication", "get_group_info", groupname);
  if(!data) return 0; // we won't set data for a non existant group.
  if(!(data->groupname && data->gid && 
    data->name && data->users))
  {
     ERROR("incomplete data for group " + groupname);
     return 0;
  }
  int i=set_group_info(groupname, data);
  return data;
}

private int set_user_list(array data)
{
  ERROR("set_user_list\n");
  if(data)
  {
    cache->store(cache_pike(data, "userlist", listtimeout));
  }
  else
    ERROR("not storing zero\n");
  return 1;
}

private int set_group_list(array data)
{
  ERROR("set_group_list\n");
  if(data)
  {
    cache->store(cache_pike(data, "grouplist", listtimeout));
  }
  else
    ERROR("not storing zero\n");
  return 1;
}

private int set_user_info(string username, mapping data)
{
  if(data)
  {
    cache->store(cache_pike(data, "user-" + username, timeout));
    if(data->uid!="")
      cache->store(cache_string(data->username, "uid-" + data->uid, timeout));
  }
  else
    ERROR("not storing zero\n");
  return 1;
}

private int set_username(int uid, string data)
{
  ERROR("set_username" + uid + "\n");
  if(data)
  {
    cache->store(cache_string(data, "uid-" + uid, timeout));
  }
  else
    ERROR("not storing zero\n");
  return 1;
}

private int set_groupname(int gid, string data)
{
  ERROR("set_groupname" + gid + "\n");
  if(data)
  {
    cache->store(cache_string(data, "gid-" + gid, timeout));
  }
  else
    ERROR("not storing zero\n");
  return 1;
}

private int set_group_info(string groupname, mapping data)
{
  ERROR("set_group_info" + groupname + "\n");
  if(data)
  {
    cache->store(cache_pike(data, "group-" + groupname, timeout));
    if(data->gid!="")
      cache->store(cache_string(data->groupname, "gid-" + data->gid, timeout));
  }
  else
    ERROR("not storing zero\n");
  return 1;
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: cachetimeout
//! Number of seconds a cached user or group entry should be kept.
//!  type: TYPE_INT
//!  name: Cache Timeout
//
//! defvar: listcachetimeout
//! Number of seconds a full user or group list should be kept.
//!  type: TYPE_INT
//!  name: List Cache Timeout
//
