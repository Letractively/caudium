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

/* This is the SQL filesystem module for Caudium */
/*
 * This module is work in progress, only READ Only access had been
 * written in this module and need some works :)
 *
 * Original author : James Tyson <james@samizdat.co.nz>
 * Original name   : LiveContent: Filesystem Module
 * Original version: 0.15
 *
 */

/* Standard includes */

#include <module.h>
inherit "module";
inherit "caudiumlib";

/* Custom includes */

#include "sqlfs.h"

/* Global vars */
object mycache;

/* Standard module methods */

//
//! module: SQL Filesystem Module
//!  This is a filesystem module where objects are stored into
//!  a SQL database. This module is only read only e.g. the database
//!  need to be populed "by hand". This module needs a configured
//!  SQL-Module to work.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_LOCATION
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";
//constant thread_safe=1;			// Should be

constant module_type = MODULE_LOCATION;
constant module_name = "SQL Filesystem Module";
constant module_doc  = "This is a filesystem module where object are stored "
                       "into a SQL database. This module is only read only "
                       "e.g. the database need to be populed \"by hand\". "
                       "This module needs a configured SQL-Module to work.";
constant module_unique = 0;

void create () {
    defvar( "fsmp", "", "The filesystems mountpoint", TYPE_STRING, "" );
    defvar( "sqldb", "mysql://localhost/sqlfs", "Database name", TYPE_STRING, "This is the name of the database as given in the SQL Databases module" );
    defvar( "ttl", 600, "Time to live (secs)", TYPE_INT, "How long should we cache objects before refreshing them from the database? Longer is faster, but uses more memory. Shorter is leaner on memory, but executes <b>lots</b> of database queries." );
}

void start (int cnt, object conf) {
    // Depends of sqltag
    module_dependencies(conf, ({ "sqltag" }));
    // Not sure about this, it empties the cache every time a config variable
    // is changed???
    mycache = object_cache( );
}

string status() {
    return mycache->status();
}

string query_location () {
    return query( "fsmp" );
}

mixed find_file ( string path, object id ) {
    if ( id->pragma[ "no-cache" ] ) {
	mycache->flush( path );
    }
    object db = id->conf->sql_connect( query( "sqldb" ) );
    object emoticon = contobj( db, mycache, path );
    return emoticon->find_file();
}

void|array find_dir ( string path, object id ) {
    if ( id->pragma[ "no-cache" ] ) {
	mycache->flush( path );
    }
    object db = id->conf->sql_connect( query( "sqldb" ) );
    object emoticon = contobj( db, mycache, path );
    return emoticon->find_dir();
}

void|string real_file ( string path, object id ) {
    if ( id->pragma[ "no-cache" ] ) {
	mycache->flush( path );
    }
    object db = id->conf->sql_connect( query( "sqldb" ) );
    object emoticon = contobj( db, mycache, path );
    return emoticon->real_file();
}

void|array stat_file( string path, object id ) {
    if ( id->pragma[ "no-cache" ] ) {
	mycache->flush( path );
    }
    object db = id->conf->sql_connect( query( "sqldb" ) );
    object emoticon = contobj( db, mycache, path );
    return emoticon->stat_file();
}

