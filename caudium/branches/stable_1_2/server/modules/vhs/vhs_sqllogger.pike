/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2005 The Caudium Group
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
constant module_name  = "VHS - SQL logger";
constant module_doc   = "This logger uses a SQL database server which has pike "
                        "support to log all access for a virtual server.<br />"
			"This module has been designed to work with mod_log_sql2 from"
			"apache distribution.";
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
}

void start() {
  num=QUERY(dbcount);
  db=db_handler( QUERY(dburl) );   
  logtable=QUERY(logtable);
}


void stop() {
  destruct(db); 		// We're done, so close the connections.
}


nomask private inline string extract_user(string from)
{
  array tmp;
  if (!from || sizeof(tmp = from/":")<2)
    return "-";
  
  return tmp[0];      // username only, no password
}

void log(object id, mapping file)  {
  string log_query, referer;
  array auth;
  object sql_conn=db->handle();


  referer = (arrayp(id->referer))?(array)id->referer*" ":(string)id->referer;

  if (!sizeof(referer)) referer = "-";
  
  
  log_query=sprintf("INSERT INTO %s (agent,bytes_sent,referer,remote_host,remote_user,"
                    "request_duration,request_method,request_protocol,"
                    "request_uri,request_args,status,time_stamp,virtual_host) VALUES("
                    "'%s', %s, '%s', '%s', '%s', '0', '%s', '%s', '%s', %s, %d,%d,'%s')",
		    logtable,
		    (string)(id->useragent||"-"),
		    (string)file->len,
		    referer,
		    (string)id->remoteaddr,
		    extract_user(id->realauth),
		    (string)id->method,
		    (string)id->prot,
		    (string)id->not_query,
                    id->query?sprintf("'?%s'",(string)id->query):"NULL",
		    (int)(file->error||200),
		    time(),
		    (string)id->misc->host,
		    );

//  perror("SQL %s\n",log_query);
  
  if(catch(sql_conn->query(log_query)))
    perror("VHS - logSQL: Error running query.\n");		
  
  db->handle(sql_conn);
  return; 
}

