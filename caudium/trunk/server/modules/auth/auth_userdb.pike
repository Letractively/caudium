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
 *
 *  FIXME: usergroup mapping may be incorrect if a user is removed from a group
 */

//
//! module: Auth Handler: User database and security
//!  This module handles the security in roxen, and uses
//!  the normal system password and user database to validate
//!  users. It also maintains the user database for all other
//!  modules in roxen, e.g. the user homepage module.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PROVIDER
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";
constant thread_safe=0;

#include <module.h>
inherit "module";
inherit "caudiumlib";

#ifdef DEBUG
#define ERROR(X) werror("UserDBAuth: " + X + "\n")
#else
#define ERROR(X) 
#endif
    
constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "Authentication Provider: User Database";
constant module_doc  = "Authenticate users against common user databases "
        "such as /etc/passwd using common system functions.";

// we can have more than one per virtual server.
constant module_unique = 0;

// Fairly weak check of password for portability.
#define CRYPTWD_CHECK(cryptwd) \
  (!!(cryptwd) && sizeof (cryptwd) >= 10 && \
   search ((cryptwd), "*") < 0 && search ((cryptwd), "!") < 0)

mapping groups, gid2group;
mapping users, uid2user;
mapping usergroups;
array fstat;

private static int last_password_read = 0;
private static int last_group_read = 0;

void report_io_error (string f, mixed... args)
{
  f = sprintf (f, @args);
#if constant (strerror)
  f += ": " + strerror (errno()) + "\n";
#else
  f += ": errno " + errno() + "\n";
#endif
  report_error (f);
}

void read_group_data_if_not_current()
{
  if (query("method") == "file" || query("method") == "shadow")
  {
    string filename=query("groupfile");
    array|int status=file_stat(filename);
    int mtime;

    if (arrayp(status))
      mtime = status[3];
    else
      return;

    if (mtime > last_group_read)
      read_group_data();
  }
}

void read_user_data_if_not_current()
{
  if (query("method") == "file" || query("method") == "shadow")
  {
    string filename=query("userfile");
    array|int status=file_stat(filename);
    int mtime;

    if (arrayp(status))
      mtime = status[3];
    else
      return;

    if (mtime > last_password_read)
      read_user_data();
  }
}


void try_find_user(string|int u)
{
  array uid;
  switch(QUERY(method))
  {
#if constant(getpwuid) && constant(getpwnam)
      case "getpwent":
        if(intp(u)) uid = getpwuid(u);
        else        uid = getpwnam(u);
        break;
        if(uid)
        {
          if(users[uid[0]])
          {
            uid2user[uid[2]][5] = uid[5];
            users[uid[0]][5] = uid[5];
          } else {
            uid2user[uid[2]] = uid;
            users[uid[0]] = uid;
          }
        }
#endif
      case "file":
        if(!equal(file_stat(QUERY(userfile)), fstat))
          read_user_data();
        break;

      case "ypmatch":
      case "niscat":
  }
}

void try_find_group(string|int g)
{
  array gid;
  switch(QUERY(method))
  {
#if constant(getgrgid) && constant(getgrnam)
      case "getpwent":
        if(intp(g)) gid = getgrgid(g);
        else        gid = getgrnam(g);
        break;
        if(gid)
        {
          if(groups[gid[0]])
          {
	      gid2group[gid[2]][5] = gid[5];
	      groups[gid[0]][5] = gid[5];
          } else {
	      gid2group[gid[2]] = gid;
	      groups[gid[0]] = gid;
          }
        }
#endif

      case "file":
        if(!equal(file_stat(QUERY(groupfile)), fstat))
          read_group_data();
        break;

      case "ypmatch":
      case "niscat":
  }
}

#if constant(getpwent)
private static array foo_users;
private static int foo_upos;
private static array foo_groups;
private static int foo_gpos;

void slow_user_update()
{
  if(!foo_users || sizeof(foo_users) != sizeof(users))
  {
    foo_users = indices(users);
    foo_upos = 0;
  }

  if(!sizeof(foo_users))
    return;
  
  if(foo_upos >= sizeof(foo_users))
    foo_upos = 0;
  try_find_user(foo_users[foo_upos++]);

  remove_call_out(slow_user_update);
  call_out(slow_user_update, 30);
}

void slow_group_update()
{
  if(!foo_groups || sizeof(foo_groups) != sizeof(groups))
  {
    foo_groups = indices(groups);
    foo_gpos = 0;
  }

  if(!sizeof(foo_groups))
    return;
  
  if(foo_gpos >= sizeof(foo_groups))
    foo_gpos = 0;
  try_find_group(foo_groups[foo_gpos++]);

  remove_call_out(slow_group_update);
  call_out(slow_group_update, 30);
}
#endif

void read_user_data()
{
  string data,u;
  array(string)  entry, tmp, tmp2;
  int foo, i;
  int original_data = 1; // Did we inherit this user list from another
  //  user-database module?
  int saved_uid;
  
  users=([]);
  uid2user=([]);
  switch(query("method"))
  {
      case "ypcat":
        object privs;
        data=Process.popen("ypcat "+query("args")+" passwd");
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        if (!data) report_io_error ("Error reading passwd database with ypcat");
        break;

      case "getpwent":
#if constant(getpwent)
        // This could be a _lot_ faster.
        tmp2 = ({ });
#if constant(geteuid)
        if(getuid() != geteuid()) privs = Privs("Reading password database");
#endif
        setpwent();
        while(tmp = getpwent())
          tmp2 += ({
            Array.map(tmp, lambda(mixed s) { return (string)s; }) * ":"
          }); 
        endpwent();
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        data = tmp2 * "\n";
        break;
#endif

      case "file":
        fstat = file_stat(query("userfile"));
        data = Stdio.read_bytes(query("userfile"));
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        if (!data) report_io_error ("Error reading passwd database from " + query ("userfile"));
        last_password_read = time();
        break;
    
      case "shadow":
        string shadow;
        array pw, a, b;
        mapping sh = ([]);
#if constant(geteuid)
        if(getuid() != geteuid()) privs=Privs("Reading password database");
#endif
        fstat = file_stat(query("userfile"));
        data=    Stdio.read_bytes(query("userfile"));
        if (data) shadow = Stdio.read_bytes(query("shadowfile"));
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        if (!data)
          report_io_error ("Error reading passwd database from " + query ("userfile"));
        else if (!shadow)
          report_io_error ("Error reading shadow database from " + query ("shadowfile"));
        else {
          foreach(shadow / "\n", shadow) {
            if(sizeof(a = shadow / ":") > 2)
              sh[a[0]] = a[1];
          }
          pw = data / "\n";
          for(i = 0; i < sizeof(pw); i++) {
            if(sizeof(a = pw[i] / ":") && sh[a[0]])
              pw[i] = `+(a[0..0],({sh[a[0]]}),a[2..])*":";
          }
          data = pw*"\n";
        }
        last_password_read = time();
        break;

      case "niscat":
#if constant(geteuid)
        if(getuid() != geteuid()) privs=Privs("Reading password database");
#endif
        data=Process.popen("niscat "+query("args")+" passwd.org_dir");
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        if (!data) report_io_error ("Error reading passwd database with niscat");
        break;
  }

  if(!data)
    data = "";

  if(query("Swashii"))
    data=replace(data, 
                 ({"}","{","|","\\","]","["}),
                 ({"е","д","ц", "Ц","Е","Д"}));

  if(QUERY(Strip))
    foreach(data/"\n", data)
    {
      if(sizeof(entry=data/":") > 6)
      {
        if (sizeof(entry[4])) {
          entry[4]=(entry[4]/",")[0];
        }
        uid2user[(int)((users[entry[0]] = entry)[2])]=entry;
      }
    }
  else
    foreach(data/"\n", data)
      if(sizeof(entry=data/":") > 6)
        uid2user[(int)((users[entry[0]] = entry)[2])]=entry;

#if constant(getpwent)
  if(QUERY(method) == "getpwent" && (original_data))
  {
      slow_user_update();
  }
#endif

  // We do need to continue calling out.. Duh.
  int delta = QUERY(update);
  if (delta > 0) {
    last_password_read=time(1);
    remove_call_out(read_user_data);
    call_out(read_user_data, delta*60);

  }
}

void read_group_data()
{
  string data,g;
  array entry, tmp, tmp2;
  int foo, i;
  int original_data = 1; // Did we inherit this group list from another
  //  user-database module?
  int saved_gid;

  usergroups=([]);  
  groups=([]);
  gid2group=([]);
  switch(query("method"))
  {
      case "ypcat":
        object privs;
#if constant(geteuid)
//  if(getuid() != geteuid()) privs = Privs("Reading password database");
#endif
        data=Process.popen("ypcat "+query("args")+" group");
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        if (!data) report_io_error ("Error reading group database with ypcat");
        break;

      case "getpwent":
#if constant(getgrent)
        // This could be a _lot_ faster.
        tmp2 = ({ });
#if constant(geteuid)
        if(getuid() != geteuid()) privs = Privs("Reading group database");
#endif
        setgrent();
        while(tmp = getgrent())
	{
          tmp2 += ({
            Array.map(tmp, lambda(mixed s) { if(arrayp(s)) return s*","; else return (string)s; }) * ":"
          }); 
	}
        endgrent();
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        data = tmp2 * "\n";
        break;
#endif

      case "file":
      case "shadow":
//     if(getuid() != geteuid()) privs = Privs("Reading password database");
        fstat = file_stat(query("groupfile"));
        data = Stdio.read_bytes(query("groupfile"));
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        if (!data) report_io_error ("Error reading group database from " + query ("groupfile"));
        last_group_read = time();
        break;
    
        case "niscat":
#if constant(geteuid)
        if(getuid() != geteuid()) privs=Privs("Reading group database");
#endif
        data=Process.popen("niscat "+query("args")+" group.org_dir");
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        if (!data) report_io_error ("Error reading group database with niscat");
        break;
  }

  if(!data)
    data = "";
  
  if(query("Swashii"))
    data=replace(data, 
                 ({"}","{","|","\\","]","["}),
                 ({"е","д","ц", "Ц","Е","Д"}));

  foreach(data/"\n", string data1)
      if(sizeof(entry=data1/":")== 4)
      {
	  if(entry[3])
	      entry[3]=(entry[3]/","-({""}));
	  foreach(entry[3], string g)
	      if(usergroups[g])
		  usergroups[g]+=({entry[0]});
	      else
		  usergroups[g]=({entry[0]});
	  groups[entry[0]] = entry;
	  gid2group[(int)entry[2]]=entry;
      }
#if constant(getpwent)
  if(QUERY(method) == "getpwent" && (original_data))
  {
    slow_group_update();
  }
#endif

  // We do need to continue calling out.. Duh.
  int delta = QUERY(update);
  if (delta > 0) {
    last_group_read=time(1);
    remove_call_out(read_group_data);
    call_out(read_group_data, delta*60);
  }
}

void create()
{
  defvar("userfile", "/etc/passwd", "Password database file",
         TYPE_FILE,
         "This file will be used if method is set to file.", 0, 
         method_is_not_file);

  defvar("groupfile", "/etc/group", "Group database file",
         TYPE_FILE,
         "This file will be used if method is set to file.", 0, 
         method_is_not_file);

  defvar("shadowfile", "/etc/shadow", "Password database shadow file",
         TYPE_FILE,
         "This file will be used if method is set to shadow.", 0, 
         method_is_not_shadow);

#if constant(getpwent)
  defvar("method", "file", "Password database request method",
         TYPE_STRING_LIST, 
         "What method to use to maintain the passwd database. "
         "'getpwent' is by far the slowest of the methods, but it "
         "should work on all systems. It will also enable an automatic "
         "passwd information updating process. Every 10 seconds the "
         "information about one user from the password database will be "
         "updated. There will also be call performed if a user is not in the "
         "in-memory copy of the passwd database."
         " The other methods are "
         "ypcat, on Solaris 2.x systems niscat, file, shadow and none"
         ". If none is selected, all auth requests will succeed, "
         "regardless of user name and password.",

         ({ "ypcat", "file", "shadow", "niscat", "getpwent", "none" }));
#else
  defvar("method", "file", "Password database request method",
         TYPE_STRING_LIST, 
         "What method to use to maintain the passwd database. The methods are "+
         "ypcat, on Solaris 2.x systems niscat, file, shadow and none"+
         ". If none is selected, all auth requests will succeed, "+
         "regardless of user name and password.",
         ({ "ypcat", "file", "shadow", "niscat", "none" }));
#endif

  defvar("args", "", "Password command arguments",
         TYPE_STRING|VAR_MORE,
         "Extra arguments to pass to either ypcat or niscat."
         "For ypcat the full command line will be 'ypcat [args] passwd'."
         " for niscat 'niscat [args] passwd.org_dir'"
         "If you do not want the passwd part, you can end your args with '#'",
         0,
         method_is_file_or_getpwent);
  

  defvar("Swashii", 1, "Turn }{| into едц", TYPE_FLAG|VAR_MORE,
         "Will make the module turn }{| into едц in the Real Name "+
         "field in the userinfo database. This is useful in a european "+
         "country, Sweden.");

  defvar("Strip", 1, "Strip finger information from fullname",
         TYPE_FLAG|VAR_MORE,
         "This will strip everyting after the first ',' character from "
         "the GECOS field of the user database.");

  defvar("update", 60,
         "Interval between automatic updates of the user database",
         TYPE_INT|VAR_MORE,
         "This specifies the interval in minutes between automatic updates "
         "of the user database.");
}

int succ, fail, nouser;

string status() {
  int cryptwd_ok = 0;
  foreach (values (users), array e)
    cryptwd_ok += CRYPTWD_CHECK (e[1]);

  return 
    ("<h1>Security info</h1>"+
     "<b>Successful auths:</b> "+(string)succ+"<br>\n" + 
     "<b>Failed auths:</b> "+(string)fail
     +", "+(string)nouser+" had the wrong username<br>\n"
     + "<p>The database has "+ sizeof(users)+" entries, "
     "of which " + cryptwd_ok + " seems to have valid passwords."
    );
}

void start(int i)
{
  ERROR("start");
  if(i<2)
  {
    read_user_data();
    read_group_data();
  }

  int delta = QUERY(update);
  if (delta > 0) {
    last_group_read=time(1);
    remove_call_out(read_group_data);
    call_out(read_group_data, delta*60);

    last_password_read=time(1);
    remove_call_out(read_user_data);
    call_out(read_user_data, delta*60);
  }
}

void stop()
{
  ERROR("stop");
}

string query_provides()
{
  return "authentication";
}

mapping|int get_user_info(string u)
{
  ERROR("get_user_info: " + u);
  int res;
  if(!u)  // user not provided.
    return 0;
  if(!users[u])
    try_find_user(u);
  if(!users[u]) return 0; // user doesn't exist.

  array groups=({});

  groups=get_groups_for_user(u);

  return(["username": users[u][0], "primary_group": get_groupname(users[u][3]), 
	"name": users[u][4], "uid": users[u][2],
	"home_directory" : users[u][5], "groups": groups,
	"_source": query("_name")]);

}

mapping|int get_username(string uid)
{
  ERROR("get_username: " + uid);

  if(!uid)
    return 0;
  if(!uid2user[(int)uid])
    try_find_user((int)uid);
  if(!uid2user[(int)uid]) return 0;
  else return uid2user[(int)uid][0];


}

mapping|int get_groupname(string gid)
{
  werror("get_groupname: " + gid);

  if(!gid)
    return 0;
  werror("looking for group...\n");
  if(!gid2group[(int)gid])
      try_find_group((int)gid);
  if(!gid2group[(int)gid]) return 0;
  else return gid2group[(int)gid][0];

}

mapping|int get_group_info(string groupname)
{
  ERROR("get_user_info: " + groupname);
  int res;
  string common_name,gid,users;

  if(!groupname)
    return 0;
  if(!groups[groupname])
      try_find_group(groupname);
  if(!groups[groupname]) return 0;

  else return(["groupname": groups[groupname][0], 
	"name": groups[groupname][0], "gid": groups[groupname][2],
	"users": groups[groupname][3], "_source": query("_name") ]);

}

array list_all_groups()
{
  ERROR("list_all_groups()");


  return indices(groups);

}
array list_all_users()
{
  ERROR("list_all_users()");

  return indices(users);

}

array get_groups_for_user(string dn)
{

  ERROR("get_groups_for_user(" + dn + ")");

  if(usergroups[dn]) return usergroups[dn];

  return ({});
}

//
//  return 1 on success, -1 on failed authentication
//    0 when user is not found, etc.
//
int authenticate(string u, string p)
{
 
  if(QUERY(method) == "none")
  {
    succ++;
    return 1;
  }

  read_user_data_if_not_current();

  if(!users[u] || !(stringp(users[u][1]) && strlen(users[u][1]) > 6))
  {
    nouser++;
    fail++;
    return 0; 
  }
  
  if(!users[u][1] || !crypt(p, users[u][1]))
  {
    fail++;
    return -1; 
  }

  succ++;

  // u is a valid user 
  return 1;
}

int may_disable() { return 0; }

int method_is_not_file()
{
  return !(QUERY(method) == "file" || QUERY(method) == "shadow");
}

int method_is_not_shadow()
{
  return QUERY(method) != "shadow";
}

int method_is_file_or_getpwent()
{
  return (QUERY(method) == "file") || (QUERY(method)=="getpwent") || 
    (QUERY(method) == "shadow");
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: file
//! This file will be used if method is set to file.
//!  type: TYPE_FILE
//!  name: Password database file
//
//! defvar: shadowfile
//! This file will be used if method is set to shadow.
//!  type: TYPE_FILE
//!  name: Password database shadow file
//
//! defvar: method
//! What method to use to maintain the passwd database. 'getpwent' is by far the slowest of the methods, but it should work on all systems. It will also enable an automatic passwd information updating process. Every 10 seconds the information about one user from the password database will be updated. There will also be call performed if a user is not in the in-memory copy of the passwd database. The other methods are ypcat, on Solaris 2.x systems niscat, file, shadow and none. If none is selected, all auth requests will succeed, regardless of user name and password.
//!  type: TYPE_STRING_LIST
//!  name: Password database request method
//
//! defvar: method
//! What method to use to maintain the passwd database. The methods are 
//!  type: TYPE_STRING_LIST
//!  name: Password database request method
//
//! defvar: args
//! Extra arguments to pass to either ypcat or niscat.For ypcat the full command line will be 'ypcat [args] passwd'. for niscat 'niscat [args] passwd.org_dir'If you do not want the passwd part, you can end your args with '#'
//!  type: TYPE_STRING|VAR_MORE
//!  name: Password command arguments
//
//! defvar: Swashii
//! Will make the module turn }{| into едц in the Real Name 
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Turn }{| into едц
//
//! defvar: Strip
//! This will strip everyting after the first ',' character from the GECOS field of the user database.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Strip finger information from fullname
//
//! defvar: update
//! This specifies the interval in minutes between automatic updates of the user database.
//!  type: TYPE_INT|VAR_MORE
//!  name: Interval between automatic updates of the user database
//
