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

// Global variables used here
object db;		// The database

void create() {
  defvar("dburl","mysql://user:pass@host/database","Database URL",
         TYPE_STRING,
         "The connection to logger database");
  defvar("timeout",600,"Timeout for SQL persistant connections",
         TYPE_INT,
         "Timeout when the connection to db will be closed");
}

void stop() {
  destruct(db);
}

void log(object id, mapping file) 
{
 if ( ( id->useragent ) && ( sizeof(id->useragent) > 1 )) {
   // We can log into db
   if(!objectp(db)) {
     // Open & create db
     db = SqlDB.DB(QUERY(timeout), QUERY(dburl), id);
   }
   if ( lower_case((id->useragent)[0..6]) == "caudium" ) {
     // This a caudium
     if (catch(db->query("INSERT INTO support (host,version,timestmp) VALUES (\""+ 
                          caudium->quick_ip_to_host(id->remoteaddr) +"\",\"" +
                          (http_decode_string(id->useragent) - "Caudium") +
                          "\",NOW())"))) {
         perror("Failed to insert sql query");
     }
   }
 }
}
