/* I'm -*-Pike-*-, dude 
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
 * $Id$
 */

//!  This Pike module provides a couple of classes that makes it possible for
//!  module programmers to get Sql Databases connection persistent with
//!  programmable values (timeout, database name, etc...).

//!   This is the DB handler itself. 
class DB {
  static private int last_db_access = 0;	// Last time when 
						// db was accessed
  static private int db_access = 0;		// Number of DB access
  static private int db_close = 0;		// Number of DB closes
  static private object db = 0;			// The database object

  static private int timeout = 0;		// Timeout to close the
						// DB.
  static private string sqlurl;			// The SqlURL
  object id;					// The Caudium Id

  //!  Create and open the database
  //! @param _timeout
  //!  The timeout used to auto-close the database is not used.
  //! @param _dburl
  //!  The dbURI used to connect to the db. The string should be on the
  //!  format dbtype://[user[:password]@@]hostname[:port][/database]. Use
  //!  the dbtype protocol to connect to the database server on the
  //!  specified host (mysql,postgres,msql,odbc,oracle,sybase...).
  //! @param _id
  //!  The Caudium Object id
  //! @returns
  //!  Nothing    
  void create(int _timeout, string _dburl, object _id) {
    timeout = _timeout;
    dburl = _dburl;
    id = _id;		// Can be dangerous if we modify here some id things.
  }

  //!  Auto-close the db if needed
  //! @returns
  //!  Nothing directly, used internally only
  void close_db() {
   if((time(1)-last_db_access) > timeout {
     db = 0;
     db_close++;
     return;
   }
   call_out(close_db,timeout);
  }

  //!  Opens the database.
  //! @returns
  //!  Nothing directly, used internally only
  private void opendb() {
    mixed err;
    last_db_access = time(1);
    db_access++;
    if(objectp(db))	// The db is already opened
	return;
    err=catch {
	db = id->conf->sql_connect(dburl);
    };
    if (err) {
	perror("Error in opening DB ("+dburl+")\n");
	if (db) 
		perror("Error is : "+db->error()+"\n");
	db = 0;
	db_close++;
	return;
    }
    call_out(close_db, timeout);
  }
 
  //!  Send a SQL query to the Sql module using Caudium's SQL handler.
  //!  The call is similar to Sql.Sql()->query() from Pike's manual.
  //! @returns
  //!  Usual Sql.Sql->query() stuff.
  //! @param q
  //!  The query to execute or a compiled query made by compile_query().
  //! @param args
  //!  The args to a sprintf() like string (see Pike Manual)
  int|array(mapping(string:mixed)) query(mixed ... args) {
  //
  // Yeah I don't use what I've defined before... But it is directly
  // sent to the SQL handler so I must define it here :P      
    opendb();
    if (!db)
      return 0;
    return db->query(@args);
  }

}
