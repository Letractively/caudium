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

#include "sqlfs-cache.h";
#include "sqlfs-read.h";
//#include "sqlfs-write.h";
#include "sqlfs-stdio_helper.h";

/* Global vars */
object fscache;

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
    defvar( "ttl", 1200, "Time to live (secs)", TYPE_INT, "How long should we cache objects before refreshing them from the database? (Default = 10min) Longer is faster, but uses more memory. Shorter is leaner on memory, but executes <b>lots</b> of database queries. If you set the TTL to 0 objects will be cached <b>forever</b> this may or may not be a good thing. YMMV" );
    defvar( "store_atime", 1, "Store a_time?", TYPE_FLAG, "a_time is the file access time. Most filesystems implement this (except for some journalling ones), if you have this turned on then it exponentially increases the number of queries against the database, thus slowing it down. It is on by default as that's the &quot;corrent&quot; thing to do. Please note that if you disable this the atime is updated in the cache, but is not written to disk." );
    // this last one needs to be modified so that it only shows if someone clicks on "More Options"
    defvar( "flatulant_cache", 0, "Cache Flatulance?", TYPE_FLAG, "Turn on &quot;Cache Flatulance&quot; that is when you click on status the cache output lists <i>every</i> object in the cache, and not just the important ones." );
    defvar( "uid", 5000, "Default UID", TYPE_INT, "Default UID to be used on file creation." );
    defvar( "gid", 1007, "Default GID", TYPE_INT, "Default GID to be used on file creation." );
}

void start (int cnt, object conf) {
    // Depends of sqltag
    module_dependencies(conf, ({ "sqltag" }));
    // Not sure about this, it empties the cache every time a config variable
    // is changed???
    // JT - Yes. Easiest way to change things if the configuration change is
    //      a new TTL for the cache.
    //      I can't think of any other reason, but I really don't want to
    //      serve up the wrong data - I know how that pisses off users.
    fscache = sqlfs_cache( query( "ttl" ), query( "flatulant_cache" ) );
}

string status() {
    // JT - someone who knows about Pike's memory management wants to look at
    //      status() and figure out a way of telling the user the size of the
    //      cache in RAM.
    return fscache->status();
}

string query_location () {
    return query( "fsmp" );
}

mixed find_file ( string path, object id ) {
    /*
     *
     * Okay. Here's what I changed: I completely re-wrote Stdio_helper
     * in an effort to make it look more like Stdio.File, and I think I
     * succeeded.
     * It seems to be working perfectly, even truncate works. So I think
     * that unless you run into something that it doesn't do then it's
     * pretty much officially stable.
     *
     */

    if ( id->pragma[ "no-cache" ] ) {
	fscache->flush( path );
    }
    object db = id->conf->sql_connect( query( "sqldb" ) );
    object readobj = sqlfs_read( db, fscache, path, query( "store_atime" ) );
    if ( readobj->get_content_ID() == 0 ) {
	return 0;
    } else if ( readobj->get_content_ID() == -1 ) {
	return -1;
    } else if ( readobj->get_file_type() == 0 ) {
	return 0;
    } else if ( readobj->get_file_type() == -1 ) {
	return -1;
    } else if ( readobj->get_file_type() == 1 ) {
	object stdio = Stdio_helper();
	stdio->__open_read( readobj );
	return stdio;
    } else if ( readobj->get_file_type() == 2 ) {
	return 0;
    }
}

void|array find_dir ( string path, object id ) {
    if ( id->pragma[ "no-cache" ] ) {
	fscache->flush( path );
    }
    object db = id->conf->sql_connect( query( "sqldb" ) );
    object readobj = sqlfs_read( db, fscache, path, query( "store_atime" ) );
    return readobj->find_dir();
}

void|string real_file ( string path, object id ) {
    return 0;
}

void|array stat_file( string path, object id ) {
    if ( id->pragma[ "no-cache" ] ) {
	fscache->flush( path );
    }
    object db = id->conf->sql_connect( query( "sqldb" ) );
    object readobj = sqlfs_read( db, fscache, path, query( "store_atime" ) );
    return readobj->stat_file();
}
