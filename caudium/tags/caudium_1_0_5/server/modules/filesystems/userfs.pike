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

//
//! module: User filesystem
//!  User filesystem. Uses the userdatabase (and thus the system passwd
//!  database) to find the home-dir of users, and then looks in a
//!  specified directory in that directory for the files requested.
//!  Usually mounted under /~, but / or /users/ would work equally well.
//!  is quite useful for IPPs, enabling them to have URLs like http://www.hostname.of.provider/customer/.
//! inherits: filesystem
//! type: MODULE_LOCATION
//! cvs_version: $Id$
//
// User filesystem. Uses the userdatabase (and thus the system passwd
// database) to find the home-dir of users, and then looks in a
// specified directory in that directory for the files requested.
// Normaly mounted under /~, but / or /users/ would work equally well.
// / is quite useful for IPPs, enabling them to have URLs like
// http://www.hostname.of.provider/customer/.

// #define USERFS_DEBUG 
// #define PASSWD_DISABLED ((us[1]=="") || (us[1][0]=='*'))
#define BAD_PASSWORD(us)	(QUERY(only_password) && \
                                 ((us[1] == "") || (us[1][0] == '*')))

#ifdef USERFS_DEBUG
# define USERFS_WERR(X) werror("USERFS: "+X+"\n")
#else
# define USERFS_WERR(X)
#endif

#include <module.h>

inherit "filesystem" : filesystem;

constant cvs_version="$Id$";
constant module_type = MODULE_LOCATION;
constant module_name = "User Filesystem";
constant module_doc  = "User filesystem. Uses the userdatabase (and thus the system passwd "
      "database) to find the home-dir of users, and then looks in a "
      "specified directory in that directory for the files requested. "
      "<p>Normaly mounted under /~, but / or /users/ would work equally well. "
      " is quite useful for IPPs, enabling them to have URLs like "
      " http://www.hostname.of.provider/customer/. ";
constant module_unique = 0;

/*
 * DB managements function
 */

int db_accesses=0;	// Usage count of DB
int last_db_access=0;	// Last time the database was accessed
object db=0;		// The database pointer

// This gets called only by call_outs, so we can avoid storing call_out_ids
// Also, I believe storing in a local variable the last time of an access
// to the database is more efficient than removing and reseting the call_outs.
// This leave a degree of uncertainty on when the DB will be effectively
// closed, but it's below the values of the module variable "timer" for sure.
void close_db()
{
  if (!QUERY(closedb))
  	return;
  if ((time(1)-last_db_access) > QUERY(timer))
  {
    db=0;
    USERFS_WERR("Closing the database");
    return;
  }
  call_out(close_db, QUERY(timer));
}

void open_db()
{
  mixed err;		// For errors during the database connexion
  last_db_access = time(1);
  db_accesses++;	// Count DB accesses here, since this called before
  			// each accesses.
  if(objectp(db))	// allready openned ?
    return;
  err=catch{
    db=Sql.sql(QUERY(sqlserver));
  };
  if(err)
  {
  	// Error ? so what ?
	werror("USERFS: Couldn't open the SQL database !!!\n");
	if (db)
	  werror("USERFS: Database interface replies : " + db->error()+"\n");
	else
	  werror("USERFS: Unknown reason.\n");
	werror("USERFS: Check the values in the configuration interface, and "
	       "that the user\n\trunning the server has adequate permissions "
	       "to access to the server.\n");
	db=0;
	return;
  }
  USERFS_WERR("Database successfully opened.\n");
  if(QUERY(closedb))
    call_out(close_db, QUERY(timer));
}

/*
 * End of DB management functions
 */


/*
 * Function dhash :
 *
 * string dhash(string what, int depth)
 *
 * what  is the string hash
 * depth is the depth of the hash
 *
 * ex : dhash("bidule", 3) will give "b/i/d/bidule"
 *
 */
string dhash(string what, int depth)
{
  return ((what/1)[0..depth-1] * "/") + "/" + what;
}

int uid_was_zero()
{
  return !(getuid() == 0); // Somewhat misnamed function.. :-)
}

int hide_searchpath()
{
  return QUERY(homedir);
}

int hide_pdir()
{
  return !QUERY(homedir);
}

int hide_directory_hash()
{
  return !(QUERY(directory_hash)&&!QUERY(homedir));
}

int hide_www_virtual_hosting()
{
  return !QUERY(virtual_hosting);
}

int hide_www_prefix()
{
  return !QUERY(www_virtual_hosting);
}

int hide_banish_list()
{
  return !QUERY(blist);
}

int hide_webhosting()
{
  return !(QUERY(webhosting)&&QUERY(virtual_hosting));
}

void create()
{
  filesystem::create();
  killvar("searchpath");
  defvar("searchpath", "NONE", "Search path", TYPE_DIR,
	 "This is where the module will find the files in the real "+
	 "file system",
	 0, hide_searchpath);

  defvar("directory_hash", 0, "Hashing: Hash userdirectory", TYPE_FLAG,
         "If set the module will hash the path to the real user directory "+
	 "e.g. if the user is <em>\"foouser\"</em> the module will try to "+
	 "access to <em>\"f/o/o/foouser\"</em> instead", 0, hide_searchpath);

  defvar("dhash_depth", 4,"Hashing: Hash depth", TYPE_INT,
         "The length of the hash depth, e.g. the number of directory to use "+
	 "for the hashing...", 0, hide_directory_hash);

  set("mountpoint", "/~");

  defvar("only_password", 1, "Password users only",
	 TYPE_FLAG, "Mount only home directories for users who has valid "
	 "passwords can be accessed through this module.");

  defvar("user_listing", 0, "Enable userlisting", TYPE_FLAG,
	 "If set a listing of all users will be shown when you access the "
	 "mount point.");

  defvar("banish_list", ({ "root", "daemon", "bin", "sys", "admin",
			   "lp", "smtp", "uucp", "nuucp", "listen",
			   "nobody", "noaccess", "ftp", "news",
			   "postmaster" }), "Banish list: Banish list",
	 TYPE_STRING_LIST, 
	 "This is a list of users who's home directories will not be "
	 "mounted.",0,hide_banish_list);
  
  defvar("blist",1,"Banish list: Enable Banish list", TYPE_FLAG,
         "If set the banish list will be activated.");

  defvar("own", 0, "Only owned files", TYPE_FLAG,
	 "If set, only files actually owned by the user will be sent "
	 "from his home directory. This prohibits users from making "
	 "confidental files available by symlinking to them. On the other "
	 "hand it also makes it harder for user to cooperate on projects.");

  defvar("virtual_hosting", 0, "Virtual User Hosting: Virtual user support", TYPE_FLAG,
	 "If set, each user will get her own site. You access the user's "
	 "with "
	 "<br><tt>http://&lt;user&gt;.domain.com/&lt;mountpoint&gt;</tt> "
	 "<br>instead of "
	 "<br><tt>http://domain.com/&lt;mountpoint&gt;&lt;user&gt;</tt>. "
	 "<p>This means that you normally set the mount point to '/'. "
	 "<p>You need to set up CNAME entries in DNS for all users, or a "
	 "regexp CNAME that matches all users, to get this to "
	 "work.");

  defvar("webhosting",0,"Web Hosting: Web Hosting", TYPE_FLAG,
         "If set, this add the options to add to this module the capabilities of "
	 "webhosting, e.g. using a SQL database you can provide a \"<i>translation</i>\" "
	 "between urls and local user names and/or home directories on where the websites are "
	 "stored on the local filesystem.<br>Example :<br>Someone on the net ask for "
	 "<em>http://www.foo.com/</em> and there is a can on the site that have this module, "
	 "if this option is activated, then you can tell this module that user \"nop\" is "
	 "the user where is stored the files for this site.",0,hide_www_virtual_hosting);

  defvar("www_virtual_hosting",0,"Virtual User Hosting: Stupid user workaround", TYPE_FLAG,
         "If set, a workaround/hack about virtual hosting is enabled. "
	 "This mean that not only the host module <b>will</b> look at the \"host\" "
	 "header to determine which users directory to access to, but also correct "
	 "some stupid users of addding \"www\" to the name of the site, e.g. :<br>"
	 "the site <tt><b>http://user.domain.com/&lt;mountpoint&gt;</b></tt> "
	 "can be <b>also</b> accessed by <tt><b>http://<u>www.</u>user.domain.com/"
	 "&lt;mountpoint&gt;</b></tt>.",0,hide_www_virtual_hosting);

  defvar("www_prefix","www","Virtual User Hosting: Workaround prefix", TYPE_STRING,
         "This is the prefix to use for \"Stupid user workaround\".", 0, hide_www_prefix);

  defvar("sqlserver","mysql://localhost/webhosting","Web Hosting: SQL Server", TYPE_STRING,
         "This is the host running SQL server with the webhosting database "
	 "where is stored all the webhosting informations.<br>"
	 "Specify an \"SQL-URL\". (see roxen manual or documentation about SQL module)",0,hide_webhosting);
  defvar("closedb",1,"Web Hosting: Close the database if not used", TYPE_FLAG,
         "Setting this will save one filedescriptor without a small "
	 "performance loss.",0,hide_webhosting);
  defvar("usecache",1,"Web Hosting: Cache DB entries", TYPE_FLAG,
         "Setting this will cache entries in the roxen cache subsystem. <br>"
	 "This can lower the load on the SQL Database on heavy loaded sites.", 0, hide_webhosting);
  defvar("timer",60,"Web Hosting: Database close timer", TYPE_INT,
         "The timer after which the database is closed",0,
	 lambda() { return !(QUERY(closedb) && QUERY(webhosting) && QUERY(virtual_hosting)); } );
  defvar("sqlquery","SELECT ftpuser FROM webhosting WHERE website=#website#","Web Hosting: SQL Query for selecting users",
         TYPE_STRING,"The SQL Query to search localuser in the SQL Database, with standart replacements :<br>"
	 "<b>#website#</b> : will replaced by the hostname asked for e.g.<br><em>http://www.foo.com/</em> will give "
	 "to the module <i>www.foo.com</i><br><em>http://www.foo.com:8000/</em> will give to the module "
	 "<i>www.foo.com:8000</i>.<br><b>NOTE:</b> The SQL Query result <b>MUST</b> be <b>UNIQUE</b>.",0,hide_webhosting);
  defvar("redirect",0,"Web Hosting: Enable redirect",TYPE_FLAG,
         "This allow the module as http redirect module for people that have a lots of url but wants to redirect the "
	 "client navigator to another site...:)",0,hide_webhosting);
  defvar("redirectquery","SELECT tourl FROM webredirect where website=#website#","Web Hosting: SQL Query for redirect",
         TYPE_STRING,"The SQL Query to search the destination of the http_redirect function. Like previous SQL Query, use "
	 "<b>#website#</b> as the hostname requested...",0,
	 lambda() { return !(QUERY(redirect) && QUERY(webhosting) && QUERY(virtual_hosting)); } );

  defvar("useuserid", 1, "Run user scripts as the owner of the script",
	 TYPE_FLAG|VAR_MORE,
	 "If set, users' CGI and Pike scripts will be run as the user whos "
	 "home directory the file was found in. This only works if the server "
	 "was started as root.",
	 0, uid_was_zero);

  defvar("pdir", "html/", "Public directory",
	 TYPE_STRING,
         "This is the directory in the home directory of the users which "
	 "contains the files that will be shown on the web. "
	 "If the module is mounted on <tt>/home/</tt>, the file "
	 "<tt>/home/anne/test.html</tt> is accessed and the home direcory "
	 "of Anne is <tt>/export/users/anne/</tt> the module will fetch "
	 "the file <tt>/export/users/anne/&lt;Public dir&gt;/test.html</tt>.",
	 0, hide_pdir);

  defvar("homedir" ,1, "Look in users homedir", TYPE_FLAG,
	 "If set, the module will look for the files in the user's home "
	 "directory, according to the <i>Public directory</i> variable. "
	 "Otherwise the files are fetched from a directory with the same "
	 "name as the user in the directory configured in the "
	 "<i>Search path</i> variable." );
}

multiset banish_list;
mapping dude_ok;
multiset banish_reported = (<>);

void start()
{
  filesystem::start();
  // We fix all file names to be absolute before passing them to
  // filesystem.pike
  path="";
  banish_list = mkmultiset(QUERY(banish_list));
  dude_ok = ([]);
  // This is needed to override the inherited filesystem module start().
}

// Query the database for table between host <-> ftpuser
// Return a string that is the ftpuser concerned by the
// site asked for... Otherwise it return a int like
// the following :
// 1 - Cannot connect to the Database
// 2 - No entry for this site.
// Params are :
// what = site to query for
int|string query_db(string what)
{
  array sql_results;
  array(string) dbinfo;
  mixed tmp;
 
  #ifdef USERFS_DEBUG
   werror("Entering query_db() for user "+what+"\n");
  #endif
  if (QUERY(usecache))
    dbinfo=cache_lookup("userfs2webhosting",what);
  if (dbinfo)
  {
    #ifdef USERFS_DEBUG
    werror("Entry in the cache is %O\n",dbinfo);
    #endif
    return dbinfo[1];
  }

  #ifdef USERFS_DEBUG
  werror("Entry not in the roxen cache\n");
  #endif
  open_db();		// Open the database if it is not allready opened

  if (!db)
  {
    #ifdef USERFS_DEBUG
    werror("Cannot connect to the database. Return nothing.");
    #endif
    return 1;
  }
  sql_results=db->query(replace(QUERY(sqlquery),"#website#","\""+what+"\""));
  if(!sql_results||!sizeof(sql_results))
  {
    USERFS_WERR("No entry in the database. Returning nothin.");
    return 2;
  }
  tmp = sql_results[0];
  // Ok now we have entries now, so we can fill the array
  dbinfo = ({
  		what,
		tmp->ftpuser
	   });
  // Now set the cache
  if (QUERY(usecache))
  	cache_set("userfs2webhosting",what,dbinfo);
  // Return the correct information :)
  USERFS_WERR(sprintf("Result : %O",dbinfo)-"\n");
  return tmp->ftpuser;
}

// Query the database for site to redirect to if this is needed
// Return the string to redirect to :) or an int like query_db()
// Params are :
//  what : the site to query to
int|string query_redir(string what)
{
  // Okay we can optimize this with query_db() but I am really
  // lazy so just copy & paste and modify it :)
  array sql_results;
  array(string) dbinfo;
  mixed tmp;
 
  #ifdef USERFS_DEBUG
   werror("Entering query_redir() for site "+what+"\n");
  #endif
  if (QUERY(usecache))
    dbinfo=cache_lookup("userfs2webredirect",what);
  if (dbinfo)
  {
    #ifdef USERFS_DEBUG
    werror("Entry in the cache is %O\n",dbinfo);
    #endif
    return dbinfo[1];
  }

  #ifdef USERFS_DEBUG
  werror("Entry not in the roxen cache\n");
  #endif
  open_db();		// Open the database if it is not allready opened

  if (!db)
  {
    #ifdef USERFS_DEBUG
    werror("Cannot connect to the database. Return nothing.");
    #endif
    return 1;
  }
  sql_results=db->query(replace(QUERY(redirectquery),"#website#","\""+what+"\""));
  if(!sql_results||!sizeof(sql_results))
  {
    USERFS_WERR("No entry in the database. Returning nothin.");
    return 2;
  }
  tmp = sql_results[0];
  // Ok now we have entries now, so we can fill the array
  dbinfo = ({
  		what,
		tmp->tourl
	   });
  // Now set the cache
  if (QUERY(usecache))
  	cache_set("userfs2webredirect",what,dbinfo);
  // Return the correct information :)
  USERFS_WERR(sprintf("Result : %O",dbinfo)-"\n");
  return tmp->tourl;
}

static array(string) find_user(string f, object id)
{
  string of = f;
  string u;

  if(QUERY(virtual_hosting)) {
    if(id->misc->host) {
      string host = (id->misc->host / ":")[0];
      if(search(host, ".") != -1) {
	sscanf(host, "%s.%*s", u);
      } else {
	u = host;
      }
      // case of www.<myloginname>
      if(QUERY(www_virtual_hosting))
      {
        if ( u == QUERY(www_prefix))
	{
	  string host = (id->misc->host / ":")[0];
	  if( search(host,".") != -1)
	  {
	    sscanf(host, QUERY(www_prefix) + ".%s.%*s",u);
	  } else u = host;
	}
      }
#ifdef USERFS_DEBUG
      werror("Host = %O, id->misc->host = %O,u = %O\n", host, id->misc->host,u);
#endif
      if(QUERY(webhosting))
      {
        #ifdef USERFS_DEBUG
	 werror("Webhosting is ON\n");
	#endif
        if ( (u == "www") || (u == host) || (intp(u)))
	{
	  #ifdef USERFS_DEBUG
	  werror("Let's look around it !\n");
	  #endif
	  string host = lower_case(id->misc->host);	// We need here the host AND the port
	  if ( sizeof(host / ":") < 2)			// No port is specified
	  {
	     host  += ":80";				// This is standart HTTP access
	     // FIXME : About SSL ?
	  }
	  if (search(host,".") != -1)
	  {
	  	// Query database
		int|string db_query_results;

		#ifdef USERFS_DEBUG
		werror("Sending SQL query for "+host+"\n");
		#endif

		db_query_results = query_db(host);	// Check for this username

		#ifdef USERFS_DEBUG
		werror("Gotcha query_db(%O) give us : %O\n",host,db_query_results);
		#endif
		if (stringp(db_query_results))		// This is a string ? So there is a user !
		{
		  u = db_query_results;
		}
		else u = (host/":")[0];			// There is no ftpuser for this host
	  }
	  else u = (host/":")[0];
	}
      }
    }
  } else {
    if((<"", "/", ".">)[f])
      return ({ 0, 0 });

    switch(sscanf(f, "%*[/]%s/%s", u, f)) {
    case 1:
      sscanf(f, "%*[/]%s", u);
      f = "";
      break;
    default:
      u="";
      // FALL_THROUGH
    case 2:
      f = "";
      // FALL_THROUGH
    case 3:
      break;
    }
  }

  USERFS_WERR(sprintf("find_user(%O) => u:%O, f:%O", of, u, f));

  return ({ u, f });
}

int|mapping|Stdio.File find_file(string f, object id)
{
  string u, of = f;

  USERFS_WERR(sprintf("find_file(%O)", f));

  [u, f] = find_user(f, id);
 
  // Check if we need to redirect the site somewhere ?
  if( (QUERY(webhosting)) && (QUERY(redirect)) )
  {
    string host = lower_case(id->misc->host);	// Take the hostname asked !

    if (sizeof(host / ":") < 2)			// No port is specified
     host += ":80";				// This is 80 port...
     						// FIXME : SSL support ?
    if (search(host,".") != -1)
    {
      // Now we can query the database :)
      int|string db_query_results;

      #ifdef USERFS_DEBUG
       werror("Sending query for http redirect for "+host+"\n");
      #endif

      db_query_results=query_redir(host);

      #ifdef USERFS_DEBUG
       werror("Gotcha query_redir(%O) gives us : %O\n",host,db_query_results);
      #endif
      if(stringp(db_query_results))
      {
        // Yes !!! This is string so we can redirect to !
	return http_redirect(db_query_results, id);
      }
    }
  }
  // We don't need any redirect, so we can continue :)

  if(!u)
    return -1;

  array(string) us;
  array(int) stat;

  if(!dude_ok[ u ] || f == "")
  {
    us = id->conf->userinfo( u, id );

    USERFS_WERR(sprintf("checking out %O: %O", u, us));
    
    if(QUERY(blist))
    if(!us || BAD_PASSWORD(us) || banish_list[u])
    { // No user, or access denied.
      USERFS_WERR(sprintf("Bad password: %O? Banished? %O",
			  (us?BAD_PASSWORD(us):1),
			  banish_list[u]));
      if(!banish_reported[u])
      {
	banish_reported[u] = 1;
	USERFS_WERR(sprintf("User %s banished (%O)...\n", u, us));
      }
      return 0;
    }
    if((f == "") && (strlen(of) && of[-1] != '/'))
    {
      redirects++;
      return http_redirect(id->not_query+"/",id);
    }

    string dir;

    if(QUERY(homedir))
      dir = us[ 5 ] + "/" + QUERY(pdir) + "/";
    else
      if(QUERY(directory_hash))
        dir = combine_path(QUERY(searchpath) + "/",dhash(u,QUERY(dhash_depth))) + "/";
      else
        dir = QUERY(searchpath) + "/" + u + "/";

    dir = replace(dir, "//", "/");

#ifdef USERFS_DEBUG
    roxen_perror(sprintf("USERFS: find_file(%O, X) => dir: %O\n",f,dir));
#endif

    // If public dir does not exist, or is not a directory
    stat = filesystem::stat_file(dir, id);
    if(!stat || stat[1] != -2)
    {
      USERFS_WERR(sprintf("Directory %O not found! (stat: %O)", dir, stat));
      return 0;	// File not found.
    }
    dude_ok[u] = dir;	// Always '/' terminated.
  }
  // For the benefit of the PHP4 module. Will set the DOCUMENT_ROOT
  // environment variable to this instead of the path to /.
  id->misc->user_document_root = dude_ok[u];
  
  f = dude_ok[u] + f;

  if(QUERY(own))
  {
    if(!us)
    {
      us = id->conf->userinfo( u, id );
      if(!us)
      {
	USERFS_WERR(sprintf("No userinfo for %O!", u));
	return 0;
      }
    }

    stat = filesystem::stat_file(f, id);

    if(!stat || (stat[5] != (int)(us[2])))
    {
      USERFS_WERR(sprintf("File not owned by user.", u));
      return 0;
    }
  }

  if(QUERY(useuserid))
    id->misc->is_user = f;

  USERFS_WERR(sprintf("Forwarding request to inherited filesystem.", u));
  return filesystem::find_file( f, id );
}

string real_file(string f, object id)
{
  string u;

  USERFS_WERR(sprintf("real_file(%O, X)", f));

  array a = find_user(f, id);

  if (!a) {
    return 0;
  }

  u = a[0];
  f = a[1];

  if(u)
  {
    array(int) fs;
    if(query("homedir"))
    {
      array(string) us;
      us = id->conf->userinfo( u, id );
      if((!us) || BAD_PASSWORD(us) || banish_list[u])
	return 0;
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
      else
	f = us[ 5 ] + QUERY(pdir) + f;
    } else
      if (QUERY(directory_hash))
        f = combine_path(QUERY(searchpath)+"/",dhash(u,QUERY(dhash_depth))) + "/" + f;
      else
        f = QUERY(searchpath) + u + "/" + f;
#ifdef USERFR_DEBUG
      roxen_perror(sprintf("USERFS: real_file(%O, X)\n", f);
#endif

    // Use the inherited stat_file
    fs = filesystem::stat_file( f,id );

    //    werror(sprintf("%O: %O\n", f, fs));
    // FIXME: Should probably have a look at this code.
    if (fs && ((fs[1] >= 0) || (fs[1] == -2)))
      return f;
  }
  return 0;
}

mapping|array find_dir(string f, object id)
{
  USERFS_WERR(sprintf("find_dir(%O, X)", f));

  array a = find_user(f, id);

  if (!a) {
    if (QUERY(user_listing)) {
      array l;
      l = id->conf->userlist(id);

      if(l) return(l - QUERY(banish_list));
    }
    return 0;
  }

  string u = a[0];
  f = a[1];

  if(u)
  {
    if(query("homedir"))
    {
      array(string) us;
      us = id->conf->userinfo( u, id );
      if(!us) return 0;
      if(QUERY(blist))
      if((!us) || BAD_PASSWORD(us))
	return 0;
      // FIXME: Use the banish multiset.
      if(QUERY(blist))
      if(search(QUERY(banish_list), u) != -1)             return 0;
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
      else
	f = us[ 5 ] + QUERY(pdir) + f;
    }
    else
      if(QUERY(directory_hash))
        f=combine_path(QUERY(searchpath)+"/",dhash(u,QUERY(dhash_depth))) + "/" +f;
      else
        f = QUERY(searchpath) + u + "/" + f;
#ifdef USERFS_DEBUG
        roxen_perror(sprintf("USERFS: find_dir(%O,X)\n",f));
#endif
    array dir = filesystem::find_dir(f, id);
    if(QUERY(virtual_hosting) && arrayp(dir))
      return ([ "files": dir ]);
    return dir;
  }
  // Mater un peu par la...
  //return id->conf->userlist(id) - QUERY(banish_list);
  return (id->conf->userlist(id)||({})) - QUERY(banish_list);
}

array(int) stat_file(string f, object id)
{
  USERFS_WERR(sprintf("stat_file(%O)", f));

  array a = find_user(f, id);

  if (!a) {
    return ({ 0, -2, 0, 0, 0, 0, 0, 0, 0, 0 });
  }

  string u = a[0];
  f = a[1];

  if(u)
  {
    array us, st;
    us = id->conf->userinfo( u, id );
    if(query("homedir"))
    {
      if(!us) return 0;
      if(QUERY(blist))
      if((!us) || BAD_PASSWORD(us))
	return 0;
      // FIXME: Use the banish multiset.
      if(QUERY(blist))
      if(search(QUERY(banish_list), u) != -1) return 0;
      if(us[5] == "") {
	// No home directory.
	return 0;
      }
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
      else
	f = us[ 5 ] + QUERY(pdir) + f;
    } else
      if (QUERY(directory_hash))
        f=combine_path(QUERY(searchpath)+"/",dhash(u,QUERY(dhash_depth)))+"/"+f;
      else
        f = QUERY(searchpath) + u + "/" + f;
#ifdef USERFR_DEBUG
	roxen_perror(sprintf("USERFR: stat_file(%O, X)\n",f);
#endif
    st = filesystem::stat_file( f,id );
    if(!st) return 0;
    if(QUERY(own) && (!us || ((int)us[2] != st[-2]))) return 0;
    return st;
  }
  return 0;
}

string query_name()
{
  return "Location: <i>" + QUERY(mountpoint) + "</i>, " +
	 (QUERY(homedir)
	  ? "Pubdir: <i>" + QUERY(pdir) +"</i>"
	  : "mounted from: <i>" + QUERY(searchpath) + "</i>");
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: searchpath
//! This is where the module will find the files in the real 
//!  type: TYPE_DIR
//!  name: Search path
//
//! defvar: directory_hash
//! If set the module will hash the path to the real user directory 
//!  type: TYPE_FLAG
//!  name: Hashing: Hash userdirectory
//
//! defvar: dhash_depth
//! The length of the hash depth, e.g. the number of directory to use 
//!  type: TYPE_INT
//!  name: Hashing: Hash depth
//
//! defvar: only_password
//! Only users who have a valid password can be accessed through this module
//!  type: TYPE_FLAG
//!  name: Password users only
//
//! defvar: user_listing
//! Enable a directory listing showing users with homepages. When the mountpoint is accessed.
//!  type: TYPE_FLAG
//!  name: Enable userlisting
//
//! defvar: banish_list
//! None of these users are valid.
//!  type: TYPE_STRING_LIST
//!  name: Banish list: Banish list
//
//! defvar: blist
//! If set the banish list will be activated.
//!  type: TYPE_FLAG
//!  name: Banish list: Enable banish list
//
//! defvar: own
//! If set, users can only send files they own through the user filesystem. This can be a problem if many users are working together with a project, but it will enhance security, since it will not be possible to link to some file the user does not own.
//!  type: TYPE_FLAG
//!  name: Only owned files
//
//! defvar: virtual_hosting
//! If set, virtual user hosting is enabled. This means that the module will look at the "host" header to determine which users directory to access. If this is set, you access the users directory with <tt><b>http://user.domain.com/&lt;mountpoint&gt;</b></tt> instead of <tt><b>http://user.domain.com/&lt;mountpoint&gt;user</b></tt>. Note that this means that you will usually want to set the mountpoint to "/". To set this up you need to add CNAME entries for all your users pointing to the IP(s) of this virtual server.
//!  type: TYPE_FLAG
//!  name: Virtual User Hosting: Virtual User Support
//
//! defvar: www_virtual_hosting
//! If set, a work around/hack about virtual hosting is enabled. This mean that not only the host module <b>will</b> look at the "host" header to determine which users directory to access, but also correct some stupid users attempt of adding "www" to the name of the site, eg. :<br />the site <tt><b>http://user.domain.com/&lt;mountpoint&gt;</b></tt> can be <b>also</b> accessed by <tt><b>http://<u>www</b>.user.domain.com/&lt;mountpoint&gt;</b></tt>.
//!  type: TYPE_FLAG
//!  name: Virtual User Hosting: Stupid user workaround
//
//! defvar: www_prefix
//! This is the prefix to add for the virtual user hosting
//!  type: TYPE_STRING
//!  name: Virtual User Hosting: Prefix to use for the user workaround
//
//! defvar: useuserid
//! If set, users cgi and pike scripts will be run as the user who owns the file, that is, not the actual file, but the user in whose dir the file was found. This only works if the server was started as root (however, it doesn't matter if you changed uid/gid after startup).
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Run user scripts as the owner of the script
//
//! defvar: pdir
//! This is where the public directory is located. If the module is mounted on /~, and the file /~per/foo is accessed, and the home-dir of per is /home/per, the module will try to file /home/per/&lt;Public dir&gt;/foo.
//!  type: TYPE_STRING
//!  name: Public directory
//
//! defvar: homedir
//! If set, the user's files are looked for in the home directory of the user, according to the <em>Public directory</em> variable. Otherwise, the <em>Search path</em> is used to find a directory with the same name as the user.
//!  type: TYPE_FLAG
//!  name: Look in users homedir
//
