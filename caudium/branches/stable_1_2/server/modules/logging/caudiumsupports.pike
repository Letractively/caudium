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
/*
 * $Id$
 */

//! module: Caudium supports logger module
//!  This module logs all access to <tt>/supports</tt> file access to a
//!  virtual server and only if user-agent name is <tt>Caudium.*</tt>. 
//!  All access is logged into a SQL database to allow graph usage.
//!  This module is used for Caudium website.
//! inherits: module
//! inherits: cadiumlib
//! type: MODULE_LOGGER
//! cvs_version: $Id$

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version   = "$Id$";
constant thread_safe   = 1;
constant module_type   = MODULE_LOGGER;
constant module_name   = "Caudium support logger module";
constant module_doc    = "This module logs all access to <tt>/supports</tt> file "
                         "access to a virtual server and only if user-agent name "
                         "is <tt>Caudium.*</tt>. All access is logged into a SQL "
                         "database to allow graph usage. This module is used for "
                         "Caudium website.";
constant module_unique = 1;

#define CL_DEBUG
#if defined(DEBUG) || defined(CL_DEBUG)
# define DW(x) werror("[CaudiumLogger] " + x + "\n")
#else
# define DW(x)
#endif


// Global variables used here
object db;		// The database
int db_accesses=0, last_db_access=0,db_err=0;

void create() {
  defvar("sqlserver","mysql://user:pass@host/database","Database URL",
         TYPE_STRING,
         "The connection to logger database");
  defvar("timer",600,"Timeout for SQL persistant connections",
         TYPE_INT,
         "Timeout when the connection to db will be closed");
  defvar("supports","/supports","File to spy",
         TYPE_STRING,
         "The file to spy for access... Usualy <tt>/supports</tt>");
}

void stop() {
  db=0;
}

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
    DW("Couldn't open SQL database!\n");
    if(db)
      DW(" database interface replies : "+db->error()+"\n");
    else
      DW(" unknown reason\n");
    DW("Check the values in the configuration interface, and "
       "that the user running the server has adequate persmissions to the "
       "server.\n");
    db=0;
    return;
  }
  DW("Database successfully opened\n");
  if(QUERY(closedb))
    call_out(close_db,QUERY(timer));
}

void log(object id, mapping file) 
{
 if ( ( id->useragent ) && ( sizeof(id->useragent) > 1 )) {
   if ( lower_case((id->useragent)[0..6]) == "caudium" ) {
     // This a caudium
     open_db(id);
     if( id->not_query == QUERY(supports)) {
  //     werror(sprintf("%O",mkmapping(indices(id),values(id))));
       mixed err = catch{
         db->query("INSERT INTO support (host,version,timestmp) VALUES (\""+ 
                   caudium->blocking_ip_to_host(id->remoteaddr) +"\",\"" +
                   (http_decode_string(id->useragent) - "Caudium/") +
                   "\",NOW())");
       };
       if(err) {
         werror("Failed to insert sql query"+err->describe());
       }
     }
   }
 }
}
