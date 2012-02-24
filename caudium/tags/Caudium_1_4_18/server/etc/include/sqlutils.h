/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
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

#ifndef SQLUTILS_H
#define SQLUTILS_H

#if defined(DEBUG)
# define SQLUDW(x) report_debug("sqlutils.h: " + x + "\n")
#else
# define SQLUDW(x)
#endif

// The version of this file
constant sqlutils_cvs_version="$Id$";

// The DB object used in Caudium
object db = 0;

// Variables used for stats and access.
private int db_accesses=0,last_db_access=0,db_err=0;

// Variables used for setup the part.
private int closedb = 1;	// Do we close the DB ? Default to yes
private int timer = 600;	// How log we keep the DB opened ? default 10min
private string sqlserver;	// The SQLURL used.

//! method: iny sqliniy(p
//!  Initialyse the DB. Must be setup BEFORE using other calls...
int sqlinit(int _closedb, int _timer, string _sqlserver) {
  closedb = _closedb;
  timer = _timer;
  sqlserver = _sqlserver;
}

//! method: void close_db()
//!  Auto-close the db is there is not access
//! returns:
//!  Nothing directly. But close the db when it is not used
void close_db() {
  if (closedb)
    return;
  if ((time(1)-last_db_access) > timer) {
    db = 0;
    SQLUDW("Closing the database : "+sqlserver);
    return;
  }
  call_out(close_db,timer);
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
  SQLUDW("Connect to "+sqlserver+" DB");
  if(id->conf->sqlconnect) {
    SQLUDW("Using internal caudium SQL system.");
    err=catch {
      db = id->conf->sqlconnect(QUERY(sqlserver));
    };
  } else {
    SQLUDW("Using non thread-safe Pike SQL system... May have some clues !");
    err=catch {
      db = Sql.Sql(QUERY(sqlserver));
    };
  }
  if(err) {
    SQLUDW("Couldn't open SQL database!");
    if(db)
      SQLUDW(" database interface replies : "+db->error());
    else
      SQLUDW(" unknown reason");
    SQLUDW("Check the values in the configuration interface, and "
           "that the user running the server has adequate persmissions to the "
           "server.");
    db=0;
    return;
  }
  SQLUDW("Database successfully opened\n");
  if(QUERY(closedb))
    call_out(close_db,timer);
}

#endif  /* SQLUTILS_H */
