/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1999 Bill Welliver <hww3@riverweb@com>
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
 * $Id$
 */

#include <module.h>
#include <caudium.h>
inherit "module";
inherit "caudiumlib";

constant module_type  = MODULE_LOGGER;
constant module_name  = "SQL logger";
constant module_doc   = "This logger uses a SQL database server which has pike "
                        "support to log all access for a virtual server.<br />"
			"Please see <tt>examples/sqllogger/</tt> files for "
			"database formats examples.";
constant module_unique= 1;
constant thread_safe  = 1;
constant cvs_version  = "$Id$";

//
//! module: SQL logger
//!  This logger uses a SQL database server which has pike support to log
//!  all access for a virtual server.<br />Please see
//!  <tt>examples/sqllogger/</tt> files for database formats examples.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_LOGGER
//! cvs_version: $Id$
//

object db;		// The db stack
int num;
string logtable; 

#if constant(thread_create)
static inherit Thread.Mutex;
#define THREAD_SAFE
#define LOCK() do { object key; catch(key=lock())
#define UNLOCK() key=0; } while(0)
#else
#undef THREAD_SAFE
#define LOCK() do {
#define UNLOCK() } while(0)
#endif


class db_handler {
#ifdef THREAD_SAFE
  static inherit Thread.Mutex;
#endif
  
  array (object) dbs = ({});
  string db_url;
  int num_dbs;  

  void create(string _dburl) {
    db_url = _dburl;
    num_dbs=num;
    mixed err;
    for(int i = 0; i < num; i++) {
      err=catch( dbs += ({ Sql.sql(db_url) }));
      if(err) perror("Error creating db object:\n" + describe_backtrace(err)+"\n");
    }
  }
  
  void|object handle(void|object d) {
    LOCK();
    int count;
    dbs -= ({0});
    if(objectp(d)) {
      if(search(dbs, d) == -1) {
	if(sizeof(dbs)>(2*num_dbs)) {
	  werror("Dropping db because of inventory...\n");
	  destruct(d);
	} else {
	  dbs += ({d});
	}
      }
    } else {
      if(!sizeof(dbs)) {
	d = Sql.sql(db_url);
      } else {
	d = dbs[0];
	dbs -= ({d});
      }
    }
    UNLOCK();
    return d;
  }
}


void create() {
  defvar("dburl", "mysql://user:pass@host/database", "Database URL", 
	 TYPE_STRING,
	 "This is the conncetion to the database in a SQL-URL.\n");
  defvar("logtable", "access_log", "Log table", 
	 TYPE_STRING,
	 "This is the table into which all client names will be put.\n");
  defvar("dbcount", 3, "Number of Connections", 
	 TYPE_INT,
	 "Number of connections to make.\n");
  defvar("failtime", 5,"Warning Timeout",
	 TYPE_INT, 
	 "Time between reconnect attempts if SQL server is down, in minutes.\n");
  defvar("sqltime", 1, "Use SQL time", TYPE_FLAG,
         "Use SQL internal SQL Time (eg SQL instruction NOW()) instead of "
	 "internal caudium computed time");
  defvar("addhost", 1, "Add hostname to request", TYPE_FLAG,
         "Add the hostname / Ip of web server to the request logged into the "
	 "database.");
  defvar("useraw", 1, "Use Raw query", TYPE_FLAG,
         "Logs all the request with the query part (eg the thing after the ? part) "
	 "instead of not query part...");
}

void start() {
  num=QUERY(dbcount);
  db=db_handler( QUERY(dburl) );   
  logtable=QUERY(logtable);
}


void stop() {
  destruct(db); 		// We're done, so close the connections.
}


void log(object id, mapping file)  {
  string log_query, username, url_query;
  array auth;
  object sql_conn=db->handle();
  
  mixed err=catch {
    if (sizeof(id->realauth)) {
      auth=id->realauth/":";
      if(sizeof(auth[0])) {
	username=auth[0];
      } else {
	username="nobody";
      }
    } else if (sizeof(id->cookies->RoxenUserID)) {
      username=id->cookies->RoxenUserID;
    } else {
      username="nobody";
    }
  };
  
  if (err) {
    username="nobody"; 
  }

  string host= id->misc->host;
  
  mapping(string:int) loctime;
  loctime = localtime((int)id->time);
  string myLogTime;   
  
  string myMonth="Err";
  switch ((int)loctime["mon"]) {
  case 0:
    myMonth="Jan";
    break;
  case 1:
    myMonth="Feb";
    break;
  case 2:
    myMonth="Mar";
    break;
  case 3:
    myMonth="Apr";
    break;
  case 4:
    myMonth="May";
    break;
  case 5:
    myMonth="Jun";
    break;
  case 6:
    myMonth="Jul";
    break;
  case 7:
    myMonth="Aug";
    break;
  case 8:
    myMonth="Sep";
    break;
  case 9:
    myMonth="Oct";
    break;
  case 10:
    myMonth="Nov";
    break;
  case 11:
    myMonth="Dec";
    break;
  }
  
  
  /* [07/May/1999:17:14:03 +0200]  */
  myLogTime = sprintf("[%02d/%s/%04d:%02d:%02d:%02d %03d00]", 
		      loctime["mday"], myMonth, loctime["year"]+1900,
		      (int)loctime["hour"], (int)loctime["min"],
		      (int)loctime["sec"], (int)loctime["timezone"]/3600 );

  if (QUERY(sqltime)) myLogTime="NOW()"; 
  else myLogTime = sprintf("'%s'",myLogTime);

  url_query = "";
  if (QUERY(addhost)) url_query += (string)host;
  if (QUERY(useraw)) url_query += id->raw_url;
  else url_query += id->not_query;

  log_query=sprintf("INSERT INTO %s VALUES('%s', %s, '%s', '%s', '%s', '%s', '%s', '%d', '%d', '%s')",
		    logtable,
		    (string)caudium->quick_ip_to_host(id->remoteaddr),
		    (string)myLogTime, 
		    (string)url_query,
		    (arrayp(id->referer))?(array)id->referer*" ":(string)id->referer,
		    (string)id->from,
		    (string)(arrayp(id->client))?id->client*" ":(string)id->client,
		    (string)username,
		    (int)file->len,
		    (int)(file->error||200),
		    (string)id->method		    
		    );
  
  if(catch(sql_conn->query(log_query)))
    perror("logSQL: Error running query.\n");		
  
  db->handle(sql_conn);
  return; 
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: dburl
//! This is the conncetion to the database in a SQL-URL.
//!
//!  type: TYPE_STRING
//!  name: Database URL
//
//! defvar: logtable
//! This is the table into which all client names will be put.
//!
//!  type: TYPE_STRING
//!  name: Log table
//
//! defvar: dbcount
//! Number of connections to make.
//!
//!  type: TYPE_INT
//!  name: Number of Connections
//
//! defvar: failtime
//! Time between reconnect attempts if SQL server is down, in minutes.
//!
//!  type: TYPE_INT
//!  name: Warning Timeout
//
//! defvar: sqltime
//! Use SQL internal SQL Time (eg SQL instruction NOW()) instead of internal caudium computed time
//!  type: TYPE_FLAG
//!  name: Use SQL time
//
