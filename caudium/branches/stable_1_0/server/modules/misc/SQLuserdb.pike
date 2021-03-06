/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
 * Copyright � 1997 Francesco Chemolli <kinkie@kame.usr.dsi.unimi.it>
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
//! module: SQL user database
//!  This module handles a SQL-based User Database. 
//!  It uses the generic-SQL pike module, so it should run on any server
//!  pike supports. This includes at least mSQL, MySql and Postgres (more
//!  could be supported in the future)
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_AUTH
//! cvs_version: $Id$
//

/*
 * Documentation can be found at 
 * http://kame.usr.dsi.unimi.it:1111/sw/roxen/sqlauth/
 * or should have been shipped along with the module.
 */

string cvs_version="$Id$";

//#define SQLAUTHDEBUG

#include <module.h>
inherit "caudiumlib";
inherit "module";

constant module_type = MODULE_AUTH;
constant module_name = "SQL user database";
constant module_doc  = "This module implements user authentication via a SQL server.<p>\n "
"For setup instruction, see the comments at the beginning of the module "
"code.<P>"
"&copy; 1997 Francesco Chemolli, distributed freely under GPL license.";
constant module_unique = 1;

#ifdef SQLAUTHDEBUG
#define DEBUGLOG(X) perror("SQLuserdb: "+X+"\n");
#else
#define DEBUGLOG(X)
#endif

int att=0, succ=0, nouser=0, db_accesses=0, last_db_access=0;
object db=0;
object caudium_conf=0;	// to access to caudium's conf object

/*
 * Object management and configuration variables definitions
 */
void create() 
{
  defvar ("sqlserver", "localhost", "SQL server",
	  TYPE_STRING,
	  "This is the host running the SQL server with the "
	  "authentication information.<br>\n"
	  "Specify an \"SQL-URL\":<ul>\n"
	  "<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@]"
	  "[<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br>\n"
	  "Valid values for \"sqlserver\" depend on which "
	  "sql-servers your pike has support for, but the following "
	  "might exist: msql, mysql, odbc, oracle, postgres.\n",
	  );

  defvar ("crypted",1,"Passwords are crypted",
          TYPE_FLAG|VAR_MORE,
          "If set, passwords are to be stored in the database "
          "encrypted with the <i>crypt(3)</i> funtion (default). "
          "If reset, passwords are stored in clear text. "
          "Storing clear passwords is a serious security threat, so "
          "encrypting them is strongly encouraged."
          );

  defvar ("table", "passwd", "Passwords table",
	  TYPE_STRING,
	  "This is the table containing the data. It is advisable not "
	  "to change it once the service has been started."
	  );

  defvar ("disable_userlist", 0, "Disable Userlist",
	  TYPE_FLAG,
	  "If this is turned on, the module will NOT honor userlist "
	  "answers. They are used if you have an user filesystem, "
	  "and try to access its mountpoint. It is recommended to "
	  "disable userlistings if you have huge users databases, "
	  "since they feature would require much memory.");

  defvar ("usecache", 1, "Cache entries",
	  TYPE_FLAG,
	  "This flag defines whether the module will cache the "
	  "database entries. Makes accesses faster, but changes "
	  "in the database will not show immediately. "
	  "<B>Recommended</B>."
	  );

  defvar ("closedb", 1, "Close the database if not used", TYPE_FLAG,
	  "Setting this will save one filedescriptor without a small "
	  "performance loss."
	  );

  defvar ("timer", 60, "Database close timer", TYPE_INT,
	  "The timer after which the database is closed",0,
	  lambda(){return !QUERY(closedb);}
	  );

  defvar ("defaultuid",
#if constant(geteuid)
	  geteuid()
#else
	  0
#endif	  
	  , "Defaults: User ID", TYPE_INT,
	  "Some modules require an user ID to work correctly. "
	  "This is the user ID which will be returned to such "
	  "requests if the information is not supplied by the database."
	  );

  defvar ("defaultgid",
#if constant(getegid)
	  getegid()
#else
	  0
#endif	  
	  , "Defaults: Group ID", TYPE_INT,
	  "Same as User ID, only it refers rather to the group."
	  );

  defvar ("defaultgecos", "", "Defaults: Gecos", TYPE_STRING,
	  "The default Gecos."
	  );

  defvar ("defaulthome", "/", "Defaults: Home Directory", TYPE_DIR, 
	  "It is possible to specify an user's home "
	  "directory in the passwords database. This is used if it's "
	  "not provided."
	  );

  defvar ("defaultshell", "/bin/sh", "Defaults: Login Shell", TYPE_FILE,
	  "Same as the default home, only referring to the user's "
	  "login shell."
	  );

  defvar ("cachetimer", 10, "Maximum cache time", TYPE_INT,
          "User information is cached in memory to speed up authorization "
	  "and to avoid unnecessary requests to the database server. This "
	  "option sets the maximum age in minute of individual cache entries. "
	  "If they are too old the entry is refreshed from the database.");

  defvar ("ignorenumber401", 30, "Number of failed 401 attempts before ignoring",
	  TYPE_INT,
	  "This option sets the number of 401 attempts allowed from a particular IP "
          "address before completely ignoring the requests. This is useful to "
	  "block potential password cracking attempts.");

  defvar ("ignoretimer401", 10, "Blocked IP ignore time", TYPE_INT,
          "The number of minutes to block an IP that exceeded the failed "
	  "authentication limit.");
}


// Start of the module
void start(int count, object conf)
{
  caudium_conf = conf;
}

/*
 * DB management functions
 */
//this gets called only by call_outs, so we can avoid storing call_out_ids
//Also, I believe storing in a local variable the last time of an access
//to the database is more efficient than removing and resetting call_outs
//This leaves a degree of uncertainty on when the DB will be effectively
//closed, but it's below the value of the module variable "timer" for sure.
void close_db() {
  if (!QUERY(closedb))
    return;
  if( (time(1)-last_db_access) > QUERY(timer) ) {
    db=0;
    DEBUGLOG("closing the database");
    return;
  }
  call_out(close_db,QUERY(timer));
}

void open_db() {
  mixed err;
  last_db_access=time(1);
  db_accesses++; //I count DB accesses here, since this is called before each
  if(objectp(db)) //already open
    return;
  if (caudium_conf->sql_connect) {	// Try to use internal Caudium SQL handler
    err=catch{
     db = caudium_conf->sql_connect(QUERY(sqlserver));
    };
  } else {
    err=catch{
     db = Sql.sql(QUERY(sqlserver));
    };
  }
  if (err) {
    perror ("SQLauth: Couldn't open authentication database!\n");
    if (db)
      perror("SQLauth: database interface replies: "+db->error()+"\n");
    else
      perror("SQLauth: unknown reason\n");
    perror ("SQLauth: check the values in the configuration interface, and "
	    "that the user\n\trunning the server has adequate permissions "
	    "to the server\n");
    db=0;
    return;
  }
  DEBUGLOG("database successfully opened");
  if(QUERY(closedb))
    call_out(close_db,QUERY(timer));
}

/*
 * Module Callbacks
 */
array(string) userinfo (string u) {
  array(string) dbinfo;
  array sql_results;
  mixed err,tmp;
  DEBUGLOG ("userinfo ("+u+")");

  if (QUERY(usecache))
    dbinfo=cache_lookup("sqlauthentries",u);
  if (dbinfo && time() < (dbinfo[7]+QUERY(cachetimer)*60)) 
    return dbinfo;

  open_db();

  if (!db) {
    perror ("SQLauth: Returning 'user unknown'.\n");
    return 0;
  }
  sql_results=db->query("select username,passwd,uid,gid,homedir,shell "
			"from "+QUERY(table)+
			" where username='"+
			db->quote(u)+"'");
  if (!sql_results||!sizeof(sql_results)) {
    DEBUGLOG ("no entry in database, returning unknown")
      return 0;
  }
  tmp=sql_results[0];
  //	DEBUGLOG(sprintf("userinfo: got %O",tmp));
  dbinfo= ({
    u,
    tmp->passwd,
    tmp->uid||QUERY(defaultuid),
    tmp->gid||QUERY(defaultgid),
    QUERY(defaultgecos),
    tmp->homedir||QUERY(defaulthome),
    tmp->shell||QUERY(defaultshell),
    time()
  });
  if (QUERY(usecache))
    cache_set("sqlauthentries",u,dbinfo);
  DEBUGLOG(sprintf("Result: %O",dbinfo)-"\n");
  return dbinfo;
  return 0;
}

array(string) userlist() {
  if (QUERY(disable_userlist))
    return ({});
  mixed err;
  array data;

  DEBUGLOG ("userlist()");
  open_db();
  if (!db) {
    perror ("SQLauth: returning empty user index!\n");
    return ({});
  }
  data=db->query("select username from "+QUERY(table));
  return data->username;
}

string user_from_uid (int u) 
{
  array data;
  if(!u)
    return 0;
  open_db(); //it's not easy to cache in this case.
  if (!db) {
    perror("SQLauth: returning no_such_user\n");
    return 0;
  }
  data=db->query("select username from " + QUERY(table) +
		 " where uid='" + (int)u +"'");
  if(sizeof(data)!=1) //either there's noone with that uid or there's many
    return 0;
  return data[0]->username;
}

array|int auth (array(string) auth, object id)
{
  string u,p;
  array(string) dbinfo, ip401;
  mixed err;

  att++;
  DEBUGLOG (sprintf("auth(%O)",auth)-"\n");

  ip401=cache_lookup("sqluser401",id->remoteaddr);
  if (ip401 && ip401[1]>QUERY(ignorenumber401)) {
    DEBUGLOG("you're in my cache");
    DEBUGLOG(time() + " > " + (ip401[2]+QUERY(ignoretimer401)*60) );
    if (time() < (ip401[2]+QUERY(ignoretimer401)*60) ) {
      DEBUGLOG("blast away killroy!");
      return ({0, auth[1], -1});
    } else {
      DEBUGLOG("removed from cache!");
      cache_remove("sqluser401",id->remoteaddr);
    }
  }

	sscanf (auth[1],"%s:%s",u,p);

	if (!p||!strlen(p)) {
		DEBUGLOG ("no password supplied by the user");
		return ({0, auth[1], -1});
	}

	if (QUERY(usecache))
		dbinfo=cache_lookup("sqlauthentries",u);

	if (!dbinfo) {
		open_db();

		if(!db) {
			DEBUGLOG ("Error in opening the database");
			return ({0, auth[1], -1});
		}
		dbinfo=userinfo(u); //cache is already set by userinfo
	}

	// I suppose that the user's password is at least 1 character long
	if (!dbinfo) {
		DEBUGLOG ("no such user");
		nouser++;
      		block401(id);
		return ({0,u,p});
	}

  if  ( dbinfo && ( time() > (dbinfo[7]+QUERY(cachetimer)*60) ) ) {
    DEBUGLOG("cache expired");
    dbinfo=userinfo(u);
  }
  
  if (QUERY(crypted)) {
    if (!crypt (p,dbinfo[1])) {
      DEBUGLOG ("password check ("+dbinfo[1]+","+p+") failed");
      block401(id);
      return ({0,u,p});
    }
  } else {
    if (p != dbinfo[1]) {
      DEBUGLOG ("clear password check (XXX,"+p+") failed");
      block401(id);
      return ({0,u,p});
    }
  }

	DEBUGLOG (u+" positively recognized");
	succ++;
	id->misc+=mkmapping(
			({"uid","gid","gecos","home","shell"}),
			dbinfo[2..6]
			);
	return ({1,u,0});
}

/*
 * Support Callbacks
 */
string status() {
  return "<H2>Security info</H2>"
    "Attempted authentications: "+att+"<BR>\n"
    "Failed: "+(att-succ+nouser)+" ("+nouser+" because of wrong username)"
    "<BR>\n"+
    db_accesses +" accesses to the database were required.<BR>\n"
    ;
}

string|void check_variable (string name, mixed newvalue)
{
  switch (name) {
   case "timer":
    if (((int)newvalue)<=0) {
      set("timer",QUERY(timer));
      return "What? Have you lost your mind? How can I close the database"
	" before using it?";
    }
    return 0;
   default:
    return 0;
  }
  return 0; //should never reach here...
}

void block401(object id) {
  array ip401;
 
  ip401 = cache_lookup("sqluser401",id->remoteaddr);
  if (!ip401) {
    ip401= ({
      id->remoteaddr,
      0,
      time()
    });
  }
  ip401[1]++;
  cache_set("sqluser401", id->remoteaddr,ip401);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: sqlserver
//! This is the host running the SQL server with the authentication information.<br />
//!Specify an "SQL-URL":<ul>
//!<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@][<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br />
//!Valid values for "sqlserver" depend on which sql-servers your pike has support for, but the following might exist: msql, mysql, odbc, oracle, postgres.
//!
//!  type: TYPE_STRING
//!  name: SQL server
//
//! defvar: crypted
//! If set, passwords are to be stored in the database encrypted with the <i>crypt(3)</i> funtion (default). If reset, passwords are stored in clear text. Storing clear passwords is a serious security threat, so encrypting them is strongly encouraged.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Passwords are crypted
//
//! defvar: table
//! This is the table containing the data. It is advisable not to change it once the service has been started.
//!  type: TYPE_STRING
//!  name: Passwords table
//
//! defvar: disable_userlist
//! If this is turned on, the module will NOT honor userlist answers. They are used if you have an user filesystem, and try to access its mountpoint. It is recommended to disable userlistings if you have huge users databases, since they feature would require much memory.
//!  type: TYPE_FLAG
//!  name: Disable Userlist
//
//! defvar: usecache
//! This flag defines whether the module will cache the database entries. Makes accesses faster, but changes in the database will not show immediately. <B>Recommended</B>.
//!  type: TYPE_FLAG
//!  name: Cache entries
//
//! defvar: closedb
//! Setting this will save one filedescriptor without a small performance loss.
//!  type: TYPE_FLAG
//!  name: Close the database if not used
//
//! defvar: timer
//! The timer after which the database is closed
//!  type: TYPE_INT
//!  name: Database close timer
//
//! defvar: defaultuid
//! Some modules require an user ID to work correctly. This is the user ID which will be returned to such requests if the information is not supplied by the database.
//!  type: TYPE_INT
//!  name: Defaults: User ID
//
//! defvar: defaultgid
//! Same as User ID, only it refers rather to the group.
//!  type: TYPE_INT
//!  name: Defaults: Group ID
//
//! defvar: defaultgecos
//! The default Gecos.
//!  type: TYPE_STRING
//!  name: Defaults: Gecos
//
//! defvar: defaulthome
//! It is possible to specify an user's home directory in the passwords database. This is used if it's not provided.
//!  type: TYPE_DIR
//!  name: Defaults: Home Directory
//
//! defvar: defaultshell
//! Same as the default home, only referring to the user's login shell.
//!  type: TYPE_FILE
//!  name: Defaults: Login Shell
//
//! defvar: cachetimer
//! User information is cached in memory to speed up authorization and to avoid unnecessary requests to the database server. This option sets the maximum age in minute of individual cache entries. If they are too old the entry is refreshed from the database.
//!  type: TYPE_INT
//!  name: Maximum cache time
//
//! defvar: ignorenumber401
//! This option sets the number of 401 attempts allowed from a particular IP address before completely ignoring the requests. This is useful to block potential password cracking attempts.
//!  type: TYPE_INT
//!  name: Number of failed 401 attempts before ignoring
//
//! defvar: ignoretimer401
//! The number of minutes to block an IP that exceeded the failed authentication limit.
//!  type: TYPE_INT
//!  name: Blocked IP ignore time
//
