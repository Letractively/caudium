/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

//! module: VHS - Virtual Hosting System - SQL
//!  Basic Virtual Hosting module in SQL mode.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PRECACHE
//! cvs_version: $Id$

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PRECACHE;
constant module_name = "VHS - Virtual Hosting System (SQL)";
constant module_doc  = "Basic Virtual Hosting module in SQL mode.";
constant module_unique = 1;

//#define VHS_DEBUG

#if defined(DEBUG) || defined(VHS_DEBUG)
# define DW(x) werror("[VHS_system] " + x + "\n")
#else
# define DW(x)
#endif

mapping (string:object) virtcache = ([]);

int virtuals;
object db;

int db_accesses=0, last_db_access=0,db_err=0;

class ConfigCache
{
  string hostname;
  string virtpath;
  string cgipath;
  string logpath;
  string owneruid;
  string redirect;
  string homedir;

  int expires;
  int createtime;
  int dynamic;
  int uidnumber;
  int gidnumber;

  void create(string owner, string host, string path,
              string cgi, string log, string home, int uid, int gid,
	      int ttl, void|string redir)
  {
    createtime = time();
    expires = createtime + ttl;
    logpath = log;
    cgipath = cgi;
    hostname = host;
    virtpath = path;
    owneruid = owner;
    redirect = redir;
    uidnumber = uid;
    gidnumber = gid;
    homedir = home;

    DW(sprintf("New ConfigCache entry: uid=%s, host=%s, path=%s, cgi=%s, logs=%s, redir=%s",
               owneruid, hostname, virtpath, cgipath||"-", logpath||"-", redirect||"-"));
  }
};

//! method: void close_db()
//!  Auto-close the db is there is not access
//! returns:
//!  Nothing directly. But close the db when it is not used
void close_db() {
  if (!QUERY(closedb))
    return;
  if ((time(1)-last_db_access) > QUERY(timer)) {
    db = 0;
    DW("Closing the database.");
    return;
  }
  call_out(close_db,QUERY(timer));
}

//! method: open_db(object id)
//!  Open the db.
//! returns:
//!  Nothing directly. Opens the db.
void open_db(object id) {
  mixed err;
  last_db_access = time(1);
  db_accesses++;
  if(objectp(db))
    return;
  if(id->conf->sqlconnect) {
    DW("Using internal caudium SQL system.");
    err=catch {
      db = id->conf->sqlconnect(QUERY(sqlserver));
    };
  } else {
    DW("Using non thread-safe Pike SQL system... May have some clues !");
    err=catch {
      db = Sql.sql(QUERY(sqlserver));
    };
  }
  if(err) {
    werror("[VHS_system] Couldn't open SQL database!\n");
    if(db)
      werror("[VHS_system] database interface replies : "+db->error()+"\n");
    else
      werror("[VHS_system] unknown reason\n");
    werror("[VHS_system] Check the values in the configuration interface, and "
           "that the user running the server has adequate persmissions to the "
           "server.\n");
    db=0;
    return;
  }
  DW("Database successfully opened\n");
  if(QUERY(closedb))
    call_out(close_db,QUERY(timer));
}

string sql_getvirt(string hostname, object id)
{
  array sql_results;
  mixed tmp;

  open_db(id);

  if (!db) {
    db_err++;
    if(db_err > QUERY(db_err_max)) return 0;
    DW("Cannot connect. Trying again..."); 
    return sql_getvirt(hostname,id);
  }

  sql_results=db->query("SELECT username,uid,gid,homedir "
                        "FROM "+QUERY(table)+" WHERE wwwdomain='"+hostname+"'");
                         
  if(!sql_results||!sizeof(sql_results)) {
    DW("No entry in the database");
    return 0;
  }
  DW("search for "+hostname);
  tmp=sql_results[0];
  DW(sprintf("got : %O",tmp));

  if (tmp)
  {
     string vpath;

     vpath = tmp->homedir||QUERY(searchpath);

     if (vpath[-1] != '/') vpath += "/";

     // owner, hostname, path, ttl
     virtcache[hostname] = ConfigCache(tmp->username,
				       hostname,
				       vpath + QUERY(wwwdir),
				       vpath + QUERY(cgidir),
				       vpath + QUERY(logdir),
				       vpath,
				       (int)tmp->uid||QUERY(defaultuid),
				       (int)tmp->gid||QUERY(defaultgid),
				       QUERY(ttl_positive));

     return vpath;
  }
  if (QUERY("lamers_mode") && hostname[0..3] == "www.")
  {
    string tmphost = hostname[4..];

    DW("Entering to lamers mode search");
    
    sql_results=db->query("SELECT username,uid,gid,homedir "
                          "FROM "+QUERY(table)+" WHERE wwwdomain='"+tmphost+"'");
                         
    if(!sql_results||!sizeof(sql_results)) {
      DW("No entry in the database");
      return 0;
    }
    DW("search for "+hostname);
    tmp=sql_results[0];
    DW(sprintf("got : %O",tmp));

    if (tmp)
    {
       string vpath;

       vpath = tmp->homedir||QUERY(searchpath);

       if (vpath[-1] != '/') vpath += "/";

       // owner, hostname, path, ttl
       virtcache[hostname] = ConfigCache(tmp->username,
				         hostname,
				         vpath + QUERY(wwwdir),
				         vpath + QUERY(cgidir),
				         vpath + QUERY(logdir),
				         vpath,
				         (int)tmp->uid||QUERY(defaultuid),
				         (int)tmp->gid||QUERY(defaultgid),
				         QUERY(ttl_positive));

       return vpath;
    }
  }
  return 0;
}

string recursive_check_virtual(object id, string hostname, void|string prefix)
{
  int ctime = time();

  if (!prefix) prefix = "";

  if (virtcache[hostname] &&
      !virtcache[hostname]->dynamic &&
      virtcache[hostname]->expires >= ctime &&
      virtcache[hostname]->virtpath)
     return virtcache[hostname]->virtpath + "/" + prefix;
  else
  {
     id->pragma["no-cache"] = 1;

     if (!virtcache[hostname] || virtcache[hostname]->expires < ctime)
     {
        DW("recursive_check_virtual: (cache miss) " + hostname + "\n");
        string ret = sql_getvirt(hostname, id);
        if (ret) return ret + QUERY(wwwdir) + prefix;
     }
     else
     {
        DW("recursive_check_virtual: (cache hit) " + hostname + "\n");
        return virtcache[hostname]->virtpath + "/" + prefix;
     }
  }
  
  if (!virtcache[hostname] || virtcache[hostname]->expires < ctime)
  {
     if (hostname == "") return 0;
   
     array hostparts = hostname / ".";
   
     DW(sprintf("recursive_check_virtual: hostparts = %O", hostparts));
   
     if (prefix != "") prefix += ".";
   
     prefix += hostparts[0];
     hostname = hostparts[1..] * ".";
   
     string ret = recursive_check_virtual(id, hostname, prefix);
   
     if (!ret) return 0;
     else if (ret[-1] != '/') ret += "/";

     ret = replace(ret, "//", "/");
   
     if (Stdio.is_dir(ret))
     {
        if (virtcache[hostname] && virtcache[hostname]->owneruid)
        {
           virtcache[prefix + "." + hostname] =
	           ConfigCache(virtcache[hostname]->owneruid,
	                       prefix + "." + hostname,
	                       ret,
			       virtcache[hostname]->cgipath,
			       virtcache[hostname]->logpath,
			       virtcache[hostname]->homedir,
			       virtcache[hostname]->uidnumber,
			       virtcache[hostname]->gidnumber,
			       QUERY(ttl_positive));
   	   virtcache[prefix + "." + hostname]->dynamic = 1;
        }
   
        return ret;
     }
     else
     {
        if (virtcache[hostname] && virtcache[hostname]->owneruid)
        {
           virtcache[prefix + "." + hostname] =
	           ConfigCache(virtcache[hostname]->owneruid,
	                       prefix + "." + hostname,
	                       ret,
			       virtcache[hostname]->cgipath,
			       virtcache[hostname]->logpath,
			       virtcache[hostname]->homedir,
			       virtcache[hostname]->uidnumber,
			       virtcache[hostname]->gidnumber,
			       QUERY(ttl_negative),
			       hostname);
   	   virtcache[prefix + "." + hostname]->dynamic = 1;
        }
   
        return ret;
     }
  }

  return 0;
}

string find_nearest_virt(string name)
{
  if (name == "") return 0;

  if (virtcache[name]) return name;

  array hostparts = name / ".";

  return find_nearest_virt(hostparts[1..] * ".");
}

void create()
{
  defvar("sqlserver", "mysql://localhost/vhs",
         "SQL:Database URL", TYPE_STRING,
	 "SQL database with virtuals data information.<br />"
  	 "Specify an \"SQL-URL\":<ul>\n"
	 "<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@]"
	 "[<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br>\n"
	 "Valid values for \"sqlserver\" depend on which "
	 "sql-servers your pike has support for, but the following "
	 "might exist: msql, mysql, odbc, oracle, postgres.\n");

  defvar("closedb",1,"SQL:Close the database if not used", TYPE_FLAG,
         "Setting this will save one filedescriptor without a small "
         "performance loss.");

  defvar("timer", 600,"SQL:Database close timer", TYPE_INT,
         "The timer after which the database is closed.",0,
         lambda() { return !QUERY(closedb);});
 
  defvar("db_err_max",10,"SQL:Max connections attempts", TYPE_INT,
         "Caudium will try to connect to SQL n times before returning an error");
 
  defvar("table","passwd","SQL:Table",TYPE_STRING,
         "Table where is stored VHS information. This can be the same table as "
         "used SQL User database");

  defvar("defaultuid",65534,"SQL:Default User ID", TYPE_INT,
         "Default user id");

  defvar("defaultgid",65534,"SQL:Default Group ID", TYPE_INT,
         "Default group id");

  defvar("defvirtual", "witch.underley.eu.org", "Default virtual path", TYPE_STRING,
	 "Redirect to this virtual, if no valid.");

  defvar("searchpath", "/var/www/", "Default path", TYPE_DIR,
	 "If no virtual found, this is default path.");

  defvar("wwwdir", "htdocs/", "WWW root directory", TYPE_STRING,
         "Directory, where are virtuals and subvirtuals stored.");

  defvar("cgidir", "cgi-bin/", "CGI directory", TYPE_STRING,
         "Directory, where are logfiles");

  defvar("logdir", "logs/", "Logs directory", TYPE_STRING,
         "Directory, mounted as cgi-bin");

  defvar("ttl_positive", 1800, "TTL:Positive TTL", TYPE_INT,
         "Time to cache positive config hits.");

  defvar("ttl_negative", 60, "TTL:Negative TTL", TYPE_INT,
         "Time to cache negative config hits.");

  defvar("lamers_mode", 1, "Enable lamers friendly mode", TYPE_FLAG,
         "Adds 'www.' prefix to each virtual.");
}

void precache_rewrite(object id)
{
  string hostname = lower_case( ( (id->host || "localhost" ) / ":" )[0] );
  string host, p;
  mapping vhs = ([]);

  id->raw_url = id->host + id->raw_url;

  if (!id->misc->host) id->misc->host = hostname;

  host = recursive_check_virtual(id, hostname);

  if (!host)
  {
    host = find_nearest_virt(hostname);

    if (!host) 
    {
        vhs->wwwpath = QUERY(searchpath);
        vhs->logpath = 0;
        vhs->cgipath = 0;
        vhs->uid = "nobody";
        vhs->redirect = QUERY(defvirtual);
        id->misc->vhs = vhs;
        return;
    }
    else
    {
      virtcache[hostname] = ConfigCache(virtcache[host]->owneruid,
            hostname, virtcache[host]->virtpath,
	    virtcache[host]->cgipath, virtcache[host]->logpath,
	    virtcache[host]->homedir, virtcache[host]->uidnumber,
	    virtcache[host]->gidnumber,
            QUERY(ttl_negative), host);
      virtcache[hostname]->dynamic = 1;
      hostname = host;
    }
  }

  vhs->wwwpath = virtcache[hostname]->virtpath;
  vhs->logpath = virtcache[hostname]->logpath;
  vhs->cgipath = virtcache[hostname]->cgipath;
  vhs->uid = virtcache[hostname]->owneruid;
  vhs->redirect = virtcache[hostname]->redirect;
  vhs->uidnumber = virtcache[hostname]->uidnumber;
  vhs->gidnumber = virtcache[hostname]->gidnumber;
  vhs->homedir = virtcache[hostname]->homedir;
  vhs->host = hostname;

  DW(sprintf("vhs = %O", vhs));

  id->misc->vhs = vhs;
}

void start()
{
  virtcache[QUERY(defvirtual)] = ConfigCache("nobody",
  QUERY(defvirtual), QUERY(searchpath), 0, 0, "/tmp", 65500, 65500,
  9999999999);
}

string status()
{
  string result = "";

  result += "<h3>Module enabled</h3>";
  result += "<h3>Info:</h3>\n";

  result += "<table><tr><td align=\"left\">Virtuals in cache:</td><td>: " +
	 sizeof(indices(virtcache)) + "</td></tr>\n" +
	 "<tr><td align=\"left\">Last SQL query:</td><td>: " +
         (last_db_access?ctime(last_db_access):"the epoch") + "</td></tr>\n" + 
	 "<tr><td align=\"left\">SQL queries:</td><td>: " +
	 db_accesses + "</td></tr>\n" + 
	 "<tr><td align=\"left\">SQL errors:</td><td>: " +
	 db_err + "</td></tr>\n" + 
         "</table><br />\n";

  result += "<h3>Virtuals in config cache:</h3>\n";

  //result += "<table bgcolor=\"#00ff80\">\n"
  result += "<table>\n"
            "<tr><td>Name</td><td>Owner</td><td>HTTP Path</td><td>Log Path</td>"
            "<td>CGI Path</td><td>Expires</td><td>Type</td></tr>";

  foreach (sort(indices(virtcache)), string name)
  {
     result += "<tr bgcolor=\"#00ff80\"><td><small>" + name + "</small></td>" +
	       "<td><small>" + (virtcache[name]->owneruid || "not known") + "</small></td>" +
               "<td><small>" + (virtcache[name]->virtpath || "not defined") + "</small></td>" +
               "<td><small>" + (virtcache[name]->logpath || "not defined") + "</small></td>" +
               "<td><small>" + (virtcache[name]->cgipath || "not defined") + "</small></td>" +
               "<td><small>" + (virtcache[name]->expires || "-") + "</small></td>" +
	       "<td><small>" + (virtcache[name]->dynamic ? "dynamic" : "static") + "</small></td>" +
	       "</tr>\n";
  }

  result += "</table>\n";

  return result;
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: sqlserver
//! SQL database with virtuals data information.<br />Specify an "SQL-URL":<ul>
//!<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@][<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br />
//!Valid values for "sqlserver" depend on which sql-servers your pike has support for, but the following might exist: msql, mysql, odbc, oracle, postgres.
//!
//!  type: TYPE_STRING
//!  name: SQL:Database URL
//
//! defvar: closedb
//! Setting this will save one filedescriptor without a small performance loss.
//!  type: TYPE_FLAG
//!  name: SQL:Close the database if not used
//
//! defvar: timer
//! The timer after which the database is closed.
//!  type: TYPE_INT
//!  name: SQL:Database close timer
//
//! defvar: db_err_max
//! Caudium will try to connect to SQL n times before returning an error
//!  type: TYPE_INT
//!  name: SQL:Max connections attempts
//
//! defvar: table
//! Table where is stored VHS information. This can be the same table as used SQL User database
//!  type: TYPE_STRING
//!  name: SQL:Table
//
//! defvar: defaultuid
//! Default user id
//!  type: TYPE_INT
//!  name: SQL:Default User ID
//
//! defvar: defaultgid
//! Default group id
//!  type: TYPE_INT
//!  name: SQL:Default Group ID
//
//! defvar: defvirtual
//! Redirect to this virtual, if no valid.
//!  type: TYPE_STRING
//!  name: Default virtual path
//
//! defvar: searchpath
//! If no virtual found, this is default path.
//!  type: TYPE_DIR
//!  name: Default path
//
//! defvar: wwwdir
//! Directory, where are virtuals and subvirtuals stored.
//!  type: TYPE_STRING
//!  name: WWW root directory
//
//! defvar: cgidir
//! Directory, where are logfiles
//!  type: TYPE_STRING
//!  name: CGI directory
//
//! defvar: logdir
//! Directory, mounted as cgi-bin
//!  type: TYPE_STRING
//!  name: Logs directory
//
//! defvar: ttl_positive
//! Time to cache positive config hits.
//!  type: TYPE_INT
//!  name: TTL:Positive TTL
//
//! defvar: ttl_negative
//! Time to cache negative config hits.
//!  type: TYPE_INT
//!  name: TTL:Negative TTL
//
//! defvar: lamers_mode
//! Adds 'www.' prefix to each virtual.
//!  type: TYPE_FLAG
//!  name: Enable lamers friendly mode
//
