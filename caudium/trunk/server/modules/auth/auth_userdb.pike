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

/*
 * User database. Reads the system password database and use it to
 * authenticate users. Interfaces with auth_master to provide stackable authentication.
*/
constant cvs_version = "$Id$";
constant thread_safe=0;

#include <module.h>
inherit "module";
inherit "caudiumlib";

#ifdef DEBUG
#define ERROR(X) werror("UserDBAuth: " + X + "\n");
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

mapping users, uid2user;
array fstat;
void read_data();

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
        if(!equal(file_stat(QUERY(file)), fstat))
          read_data();
        break;

      case "ypmatch":
      case "niscat":
  }
}


void read_data_if_not_current()
{
  if (query("method") == "file" || query("method") == "shadow")
  {
    string filename=query("file");
    array|int status=file_stat(filename);
    int mtime;
    
    if (arrayp(status))
      mtime = status[3];
    else
      return;
    
    if (mtime > last_password_read)
      read_data();
  }
}

private static int last_password_read = 0;

#if constant(getpwent)
private static array foo_users;
private static int foo_pos;

void slow_update()
{
  if(!foo_users || sizeof(foo_users) != sizeof(users))
  {
    foo_users = indices(users);
    foo_pos = 0;
  }

  if(!sizeof(foo_users))
    return;
  
  if(foo_pos >= sizeof(foo_users))
    foo_pos = 0;
  try_find_user(foo_users[foo_pos++]);

  remove_call_out(slow_update);
  call_out(slow_update, 30);
}
#endif

void read_data()
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
#if constant(geteuid)
//  if(getuid() != geteuid()) privs = Privs("Reading password database");
#endif
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
//     if(getuid() != geteuid()) privs = Privs("Reading password database");
        fstat = file_stat(query("file"));
        data = Stdio.read_bytes(query("file"));
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        if (!data) report_io_error ("Error reading passwd database from " + query ("file"));
        last_password_read = time();
        break;
    
      case "shadow":
        string shadow;
        array pw, a, b;
        mapping sh = ([]);
#if constant(geteuid)
        if(getuid() != geteuid()) privs=Privs("Reading password database");
#endif
        fstat = file_stat(query("file"));
        data=    Stdio.read_bytes(query("file"));
        if (data) shadow = Stdio.read_bytes(query("shadowfile"));
        if (objectp(privs)) {
          destruct(privs);
        }
        privs = 0;
        if (!data)
          report_io_error ("Error reading passwd database from " + query ("file"));
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

/* Two loops for speed.. */
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
    slow_update();
#endif

  // We do need to continue calling out.. Duh.
  int delta = QUERY(update);
  if (delta > 0) {
    last_password_read=time(1);
    remove_call_out(read_data);
    call_out(read_data, delta*60);
  }
}

void create()
{
  defvar("file", "/etc/passwd", "Password database file",
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
    read_data();
  /* Automatic update */
  int delta = QUERY(update);
  if (delta > 0) {
    last_password_read=time(1);
    remove_call_out(read_data);
    call_out(read_data, delta*60);
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

  return(["username": users[u][0], "primary_group": users[u][3], 
	"name": users[u][4], "uid": users[u][2],
	"home_directory" : users[u][5], "groups": groups,
	"_source": query("_name")]);

}

mapping|int get_username(string uid)
{
  ERROR("get_username: " + uid);

  if(!uid)
    return 0;
  if(!uid2user[uid])
    try_find_user(uid);
  return uid2user[uid][0];


}

mapping|int get_groupname(string gid)
{
  ERROR("get_groupname: " + gid);

  if(!gid)
    return 0;

}

mapping|int get_group_info(string groupname)
{
  ERROR("get_user_info: " + groupname);
  int res;
  string common_name,gid,users;

  if(!groupname)
    return 0;

    return(["groupname": groupname, 
	"name": common_name, "gid": gid,
	"users": users, "_source": query("_name") ]);

}

array list_all_groups()
{
  ERROR("list_all_groups()");

  array groups=({});

  return groups;

}
array list_all_users()
{
  ERROR("list_all_users()");

  return indices(users);

}

array get_groups_for_user(string dn)
{

  ERROR("get_groups_for_user(" + dn + ")");

  array groups=({});

  return groups;
}

array get_users_for_group(string dn)
{

  ERROR("get_users_for_group(" + dn + ")");

  array users=({});

  return users;
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

  read_data_if_not_current();

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

