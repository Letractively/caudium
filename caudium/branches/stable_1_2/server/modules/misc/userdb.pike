/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2003 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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
//! module: User database and security
//!  This module handles the security in roxen, and uses
//!  the normal system password and user database to validate
//!  users. It also maintains the user database for all other
//!  modules in roxen, e.g. the user homepage module.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_AUTH
//! cvs_version: $Id$
//

/*
 * User database. Reads the system password database and use it to
 * authenticate users.
 */

constant cvs_version = "$Id$";

#include <module.h>
inherit "module";
inherit "caudiumlib";

// import Stdio;
// import Array;

constant module_type = MODULE_AUTH;
constant module_name = "User database and security";
constant module_doc  = "This module handles the security in roxen, and uses "
	"the normal system password and user database to validate "
	"users. It also maintains the user database for all other "
	"modules in roxen, e.g. the user homepage module.";
constant module_unique = 1;

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

array(string) userinfo(string u) 
{
  if(!users[u])
    try_find_user(u);
  return users[u];
}

array(string) userlist() { 
  return indices(users);
}

string user_from_uid(int u) 
{ 
  if(!uid2user[u])
    try_find_user(u);
  return uid2user[u]; 
}

#define ipaddr(x,y) (((x)/" ")[y])

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
  

  defvar("Swashii", 1, "Turn }{| into Swashii", TYPE_FLAG|VAR_MORE,
	 "Will make the module turn }{| into Swashii in the Real Name "+
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
		 ({"�","�","�", "�","�","�"}));

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

void start(int i)
{
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
  
#if constant(Crypto.crypt_md5)
  if(!users[u][1]) || (users[u][1][0..2 == "$1$" && Crypto.crypt_md5(p, users[u][1]) == users[u][1]) || !crypt(p, users[u][1]))
#else
  if(!users[u][1] || !crypt(p, users[u][1]))
#endif
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
//     + "<P>The netgroup database has "+sizeof(group)+" entries"
     + "<h3>Failure by host</h3>" +
     Array.map(indices(failed), lambda(string s) {
       return caudium->quick_ip_to_host(s) + ": "+failed[s]+"<br>\n";
     }) * "" 
);
}

int may_disable() { return 0; }


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
//! Will make the module turn }{| into Swashii in the Real Name 
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Turn }{| into Swashii
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
