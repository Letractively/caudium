/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

int db_accesses=0, last_db_access=0,db_err=0;

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

