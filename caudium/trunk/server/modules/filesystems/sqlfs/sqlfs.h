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


/*
 * include for sqlfs.pike
 *
 * $Id$
 */


class fake_Stdio {
    /*
     * This is here to let me hand roxen a Stdio.File object even when
     * the file doesnt actually exist on the filesystem.
     * It seriously needs a tidy.
     *
     * TODO: int|string read()
     *         - needs to be tidied
     *         - needs to work with partial reads properly
     */

    mapping fake_file = ([ ]);
    int upto = 0;

    int tell() {
	return upto;
    }

    int|string read( void|int nbytes ) {
	// FIXME: This is a hack coz bufferred reads don't work properlike.
	//        Roxen seems to be only wanting 16386 bytes of the file, then
        //        closing the handle. Read up on stuff, I guess.
	nbytes = 0;

	if ( !fake_file[ "file_contents" ] ) {
	    return 0;
	}
	if ( nbytes > 0 ) {
	    if ( upto > 0 ) {
		int upto2 = upto;
		upto += nbytes;
		return fake_file[ "file_contents" ][ upto2..nbytes ];
	    } else {
                upto += nbytes;
		return fake_file[ "file_contents" ][ 0..nbytes ];
	    }
	} else if ( nbytes == 0 ) {
	    return fake_file[ "file_contents" ];
	}
    }

    void create( mapping file ) {
	/* I expect a mapping containing the following things:
	 "file_contents" : string
	 */
	fake_file = file;
    }

    array|int stat() {
	if ( !fake_file[ "stat" ] ) {
	    return 0;
	} else {
	    return fake_file[ "stat" ];
	}
    }

    int seek( int pos ) {
	if ( pos < 0 ) {
	    upto = sizeof( fake_file[ "file_contents" ] ) - pos;
            return upto;
	} else {
	    upto = pos;
            return upto;
	}
    }

    int open( void|string filename, void|string how, void|int mode ) {
	return 1;
    }

    int close( void|string how ) {
	return 1;
    }

    int truncate( int length ) {
	if ( sizeof( fake_file[ "file_contents" ] ) < length ) {
            return 0;
	} else {
	    fake_file[ "file_contents" ] = fake_file[ "file_contents" ][ 0..length ];
	    return 1;
	}
    }

}

class contobj {
    /*
     * This is the content object object (confused yet?)
     * -------------------------------------------------
     * if cloned without a path then we assume you are creating a new object
     * to be stored.
     * else, we assume your trying to retrieve the object, or some information
     * about the object.
     *
     * TODO: void set_new_directory()
     *       void set_whole_new_file()
     *       void set_file_type()
     *       private array(string) mode_to_perms()
     *       private int perms_to_mode()
     */

    /*
     * Global Variables
     * ----------------
     * We want to be able to keep the database connection global for the
     * whole class, and not just for each method.
     * Also, we create an object to load the object_cache class into,
     * this saves us on selects once the data is in the cache.
     */
    object db;
    object cache;
    string path;

    /*
     * Constructor
     * -----------
     * I want to recieve a database cursor object, a cache object (see class
     * object_cache) and optionally a path.
     */

    void create ( object db_conn, object obj_cache, void|string file_path ) {
        /* Please pass me a database connection to use */
	db = db_conn;
        cache = obj_cache;
	if ( stringp( file_path ) ) {
            path = file_path;
	}
    }

    /*
     * General purpose methods
     * -----------------------
     * These are methods that are used inside the object only.
     * They should be private.
     */

    private string mysql_safe ( string encode_me ) {
	return replace( encode_me, ({ "\"", "'", "\\" }), ({ "\\\"" , "\\'", "\\\\" }) );
    }


    /*
     * "Get" Methods
     * -------------
     * These methods are for getting information out of the class.
     * ie. in this case they are for retrieving information about the
     * content object.
     */

    int get_content_ID () {
        /*
	 * Returns the ID field from the content table in the database that
	 * we have been assigned the handle to.
	 * We have to do some fancy recursive lookups and things to make sure
	 * that we get the right file from the right place.
	 * Also, anything that looks like /_internal-retrieve/15 means that we
	 * have to manually retrieve content.ID = 15 and return it.
	 */
	if ( path == "" ) {
	    return -1;
	}
	if ( !cache->have( path, "content_ID" ) ) {
	    array dirs = path / "/" - ({""});
	    if ( (sizeof(dirs)>=1) && (dirs[ 0 ] == "_internal-retrieve") ) {
		// skip straight to manual retrieval.
		int retval;
		if ( catch ( sscanf( dirs[ 1 ], "%d", retval ) ) ) {
		    return 0;
		} else {
		    return retval;
		}
	    } else {
                int depth;
		string dir_part;
                int ID;
		foreach( dirs, dir_part ) {
		    string query;
		    if ( depth == 0 ) {
			query = "select ID from allocation where filename = '" + mysql_safe( dir_part ) + "' and parent_ID is null";
		    } else {
			query = "select ID from allocation where filename = '" + mysql_safe( dir_part ) + "' and parent_ID = " + sprintf( "%d", ID );
		    }
		    object result;
		    if ( catch( result = db->big_query( query ) ) ) {
			throw( ({ "Unable to retrieve content identifier from the database.", backtrace() }) );
		    }
		    if ( result->num_rows() == 0 ) {
                        cache->store( path, "content_ID", 0 );
			return 0;
		    } else {
			array row = result->fetch_row();
			    sscanf( row[ 0 ], "%d", ID );
		    }
                depth++;
		}
                cache->store( path, "content_ID", ID );
		return ID;
	    }
	} else {
	    return cache->retrieve( path, "content_ID" );
	}
    }

    int get_atime() {
	if ( !cache->have( path, "a_time" ) ) {
	    int content_ID = get_content_ID();
	    string query = "select unix_timestamp(content_info.a_time) from content, content_info where content_info.ID = content.info_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve access time from content object", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row;
	    row = result->fetch_row();
	    int timestamp;
	    sscanf( row[ 0 ], "%d", timestamp );
            cache->store( path, "a_time", timestamp );
	    return timestamp;
	} else {
	    return cache->retrieve( path, "a_time" );
	}
    }

    int get_mtime() {
	if ( !cache->have( path, "m_time" ) ) {
	    int content_ID = get_content_ID();
	    string query = "select unix_timestamp(content_info.m_time) from content, content_info where content_info.ID = content.info_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve modification time from content object", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row;
	    row = result->fetch_row();
	    int timestamp;
	    sscanf( row[ 0 ], "%d", timestamp );
            cache->store( path, "m_time", timestamp );
	    return timestamp;
	} else {
	    return cache->retrieve( path, "m_time" );
	}
    }

    int get_ctime() {
	if ( !cache->have( path, "c_time" ) ) {
	    int content_ID = get_content_ID();
	    string query = "select unix_timestamp(content_info.c_time) from content, content_info where content_info.ID = content.info_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve creation time from content object", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row;
	    row = result->fetch_row();
	    int timestamp;
	    sscanf( row[ 0 ], "%d", timestamp );
            cache->store( path, "c_time", timestamp );
	    return timestamp;
	} else {
	    return cache->retrieve( path, "c_time" );
	}
    }

    int get_uid() {
	if ( !cache->have( path, "uid" ) ) {
	    int content_ID = get_content_ID();
	    string query = "select uid from content, content_info where content_info.ID = content.info_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve uid from content object", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row;
	    row = result->fetch_row();
	    int uid;
	    sscanf( row[ 0 ], "%d", uid );
	    cache->store( path, "uid", uid );
	    return uid;
	} else {
	    return cache->retrieve( path, "uid" );
	}
    }

    int get_gid() {
	if ( !cache->have( path, "gid" ) ) {
	    int content_ID = get_content_ID();
	    string query = "select gid from content, content_info where content_info.ID = content.info_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve gid from content object", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row;
	    row = result->fetch_row();
	    int gid;
	    sscanf( row[ 0 ], "%d", gid );
            cache->store( path, "gid", gid );
	    return gid;
	} else {
	    return cache->retrieve( path, "gid" );
	}
    }

    int get_uperms() {
	if ( !cache->have( path, "u_perms" ) ) {
	    int content_ID = get_content_ID();
	    string query = "select u_perms from content, content_info where content_info.ID = content.info_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve gid from content object", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row;
	    row = result->fetch_row();
	    array perms = row[ 0 ] / ",";
            int val;
            string part;
	    foreach( perms, part ) {
		if ( part == "r" ) {
		    val += 4;
		} else if ( part == "w" ) {
		    val += 2;
		} else if ( part == "x" ) {
		    val += 1;
		}
	    }
	    cache->store( path, "u_perms", val );
            return val;
	} else {
	    return cache->retrieve( path, "u_perms" );
	}
    }

    int get_gperms() {
	if ( !cache->have( path, "g_perms" ) ) {
	    int content_ID = get_content_ID();
	    string query = "select g_perms from content, content_info where content_info.ID = content.info_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve gid from content object", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row;
	    row = result->fetch_row();
	    array perms = row[ 0 ] / ",";
            int val;
            string part;
	    foreach( perms, part ) {
		if ( part == "r" ) {
		    val += 4;
		} else if ( part == "w" ) {
		    val += 2;
		} else if ( part == "x" ) {
		    val += 1;
		}
	    }
	    cache->store( path, "g_perms", val );
            return val;
	} else {
	    return cache->retrieve( path, "g_perms" );
	}
    }

    int get_aperms() {
	if ( !cache->have( path, "a_perms" ) ) {
	    int content_ID = get_content_ID();
	    string query = "select a_perms from content, content_info where content_info.ID = content.info_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve gid from content object", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row;
	    row = result->fetch_row();
	    array perms = row[ 0 ] / ",";
            int val;
            string part;
	    foreach( perms, part ) {
		if ( part == "r" ) {
		    val += 4;
		} else if ( part == "w" ) {
		    val += 2;
		} else if ( part == "x" ) {
		    val += 1;
		}
	    }
	    cache->store( path, "a_perms", val );
            return val;
	} else {
	    return cache->retrieve( path, "a_perms" );
	}
    }

    int get_file_type() {
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return 0;
	}
	if ( !cache->have( path, "file_type" ) ) {
	    string query = "select file_type from content where ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve object meta data from database.", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row = result->fetch_row();
	    if ( row[ 0 ] == "f" ) {
		cache->store( path, "file_type", 1 );
		return 1;
	    } else if ( row[ 0 ] == "d" ) {
		cache->store( path, "file_type", -1 );
		return -1;
	    } else if ( row[ 0 ] == "c" ) {
		cache->store( path, "file_type", 2 );
		return 2;
	    }
	} else {
	    return cache->retrieve( path, "file_type" );
	}
    }

    void|array get_directory_listing() {
	if ( !cache->have( path, "dir_listing" ) ) {
	    int content_ID = get_content_ID();
	    string query;
	    if ( path == "" ) {
		query = "select filename from allocation where parent_ID is null";
	    } else {
		if ( content_ID == 0 ) {
		    return 0;
		}
		query = "select filename from allocation where parent_ID = " + sprintf( "%d", content_ID );
	    }
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to get directory listing from database.", backtrace() }) );
	    }
	    array retval = ({ });
	    array row;
	    while ( row = result->fetch_row() ) {
		retval += ({ row[ 0 ] });
	    }
            cache->store( path, "dir_listing", retval );
	    return retval;
	} else {
	    return cache->retrieve( path, "dir_listing" );
	}
    }

    int get_file_size() {
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return 0;
	}
	if ( !cache->have( path, "file_size" ) ) {
	    string query = "select octet_length( content_object.object ) from content_object, content where content.object_ID = content_object.ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve object meta data from the database.", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row = result->fetch_row();
	    int file_size;
	    sscanf( row[ 0 ], "%d", file_size );
	    cache->store( path, "file_size" , file_size );
	    return file_size;
	} else {
	    return cache->retrieve( path, "file_size" );
	}
    }

    int|string get_file_contents() {
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return 0;
	} else if ( cache->have( path, "file_contents" ) ) {
            return cache->retrieve( path, "file_contents" );
	} else {
	    string query = "select content_object.object from content_object, content where content_object.ID = content.object_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve object data from the database.", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    } else {
		array row = result->fetch_row();
		cache->store( path, "file_contents", row[ 0 ] );
                set_atime();
		return row[ 0 ];
	    }
	}
    }

    /*
     * "Set" Methods
     * -------------
     * These are for updating data about the content object.
     * These are probably for creating a new piece of content or for updating
     * a pre-existing object.
     */

    void set_atime() {
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "select info_ID from content where ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to get object metadata from the database.", backtrace() }) );
	}
	array row;
	if ( result->num_rows() == 0 ) {
	    return;
	}
	row = result->fetch_row();
	query = "update content_info set a_time = now() where ID = " + row[ 0 ];
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to update object metadata.", backtrace() }) );
	}
        cache->store( path, "a_time", time() );
    }

    void set_ctime() {
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "select info_ID from content where ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to get object metadata from the database.", backtrace() }) );
	}
	array row;
	if ( result->num_rows() == 0 ) {
	    return;
	}
	row = result->fetch_row();
	query = "update content_info set c_time = now() where ID = " + row[ 0 ];
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to update object metadata.", backtrace() }) );
	}
        cache->store( path, "c_time", time() );
    }

    void set_mtime() {
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "select info_ID from content where ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to get object metadata from the database.", backtrace() }) );
	}
	array row;
	if ( result->num_rows() == 0 ) {
	    return;
	}
	row = result->fetch_row();
	query = "update content_info set m_time = now() where ID = " + row[ 0 ];
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to update object metadata.", backtrace() }) );
	}
        cache->store( path, "m_time", time() );
    }

    void set_uid( int uid ) {
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "select info_ID from content where ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to get object metadata from the database.", backtrace() }) );
	}
	array row;
	if ( result->num_rows() == 0 ) {
	    return;
	}
	row = result->fetch_row();
	query = "update content_info set uid = " + sprintf( "%d", uid ) + " where ID = " + sprintf( "%D", row[ 0 ] );
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to update object metadata.", backtrace() }) );
	}
        cache->store( path, "uid", uid );
    }

    void set_gid( int gid ) {
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "select info_ID from content where ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to get object metadata from the database.", backtrace() }) );
	}
	array row;
	if ( result->num_rows() == 0 ) {
	    return;
	}
	row = result->fetch_row();
	query = "update content_info set gid = " + sprintf( "%d", gid ) + " where ID = " + sprintf( "%D", row[ 0 ] );
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to update object metadata.", backtrace() }) );
	}
        cache->store( path, "gid", gid );
    }

    void set_uperms( string perms ) {
        /* I expect a string containing something like "r,w,x" */
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "select info_ID from content where ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to get object metadata from the database.", backtrace() }) );
	}
	array row;
	if ( result->num_rows() == 0 ) {
	    return;
	}
	row = result->fetch_row();
	query = "update content_info set u_perms = '" + perms + "' where ID = " + sprintf( "%D", row[ 0 ] );
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to update object metadata.", backtrace() }) );
	}
        cache->flush( path, "u_perms" );
    }

    void set_gperms( string perms ) {
        /* I expect a string containing something like "r,w,x" */
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "select info_ID from content where ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to get object metadata from the database.", backtrace() }) );
	}
	array row;
	if ( result->num_rows() == 0 ) {
	    return;
	}
	row = result->fetch_row();
	query = "update content_info set g_perms = '" + perms + "' where ID = " + sprintf( "%D", row[ 0 ] );
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to update object metadata.", backtrace() }) );
	}
        cache->flush( path, "g_perms" );
    }

    void set_aperms( string perms ) {
        /* I expect a string containing something like "r,w,x" */
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "select info_ID from content where ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to get object metadata from the database.", backtrace() }) );
	}
	array row;
	if ( result->num_rows() == 0 ) {
	    return;
	}
	row = result->fetch_row();
	query = "update content_info set a_perms = '" + perms + "' where ID = " + sprintf( "%D", row[ 0 ] );
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to update object metadata.", backtrace() }) );
	}
        cache->flush( path, "a_perms" );
    }

    void set_filename( string filename ) {
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "update allocation set filename = '" + mysql_safe( filename ) + "' where content_ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to rename file.", backtrace() }) );
	}
        set_mtime();
	cache->flush( path );
    }

    void set_contents() {
    }

    void set_whole_new_directory() {
	// TODO: Insert a new directory into the database.
	// Requires: insert into allocation
	//           insert into content
        //           insert into content_info
    }

    void set_whole_new_file() {
	// TODO: Insert a new file into the database.
	// Requires: insert into allocation
	//           insert into content
	//           insert into content_info
        //           insert into content_object
    }

    void set_file_type() {
	// TODO: Change file record in the database.
	// Requires: update allocation
    }

    /* Roxen MODULE_LOCATION API Compatibility
     * ---------------------------------------
     * These shouldnt really be here, but I wanted to keep as much processing
     * as possible away from the module itself.
     */

    mixed find_file () {
	/* Roxen API Compatibility */
	int content_ID = get_content_ID();
	if ( content_ID == 0 ) {
            /* get_content_ID() was uable to locate the object. tell Roxen. */
	    return 0;
	} else if ( content_ID == -1 ) {
	    return -1;
	}
	int file_type = get_file_type();
	if ( file_type == 0 ) {
	    return 0;
	} else if ( file_type == -1 ) {
	    return -1;
	} else if ( file_type == 1 ) {
	    // This is magic. Send back a filehandle?
	    int uperms = get_uperms();
	    int gperms = get_gperms();
	    int aperms = get_aperms();
            string perms = sprintf( "%d", uperms ) + sprintf( "%d", gperms ) + sprintf( "%d", aperms );
	    int mode;
            sscanf( perms, "%d", mode );
	    object file = fake_Stdio( ([ "file_contents" : get_file_contents(),
					 "stat" : ({ mode, get_file_size(), get_atime(), get_mtime(), get_ctime(), get_uid(), get_gid() })
                                         ]) );
            return file;
	} else if ( file_type == 2 ) {
	    // This is livecontent. Send back a page?
            return 0;
	}
    }

    void|array find_dir () {
	/* Roxen API Compatibility */
	int content_ID = get_content_ID();
	if ( content_ID != 0 ) {
	    return get_directory_listing();
	}
    }

    /* not needed.
     void|string real_file () {
     // Roxen API Compatibility
     return 0;
     }
     */

    void|array stat_file () {
	/* Roxen API Compatibility */
	int content_ID = get_content_ID();
	if ( content_ID != 0 ) {
	    int file_type = get_file_type();
            int mode;
	    int uperms = get_uperms();
	    int gperms = get_gperms();
	    int aperms = get_aperms();
	    string perms = sprintf( "%d", uperms ) + sprintf( "%d", gperms ) + sprintf( "%d", aperms );
            sscanf( perms, "%d", mode );
            int size;
	    if ( file_type == -1 ) {
                size = -2;
	    } else {
                size = get_file_size();
	    }
	    return ({ mode, size, get_atime(), get_mtime(), get_ctime(), get_uid(), get_gid() });
	}
    }
}

class object_cache {
    /*
     * I am the object cache object.
     * -----------------------------
     * I maintain a memory cache of all things that are asked of class
     * contobj(), I also age these entries, so that if they are too old
     * by the time they are asked for again, I discard what I have and
     * leave it at that.
     * If anyone knows a way for me to actively remove things that are too
     * old that would be great. I need to save memory.
     *
     * TODO: General tidy up
     *        - Most of the functionality should be removed from the public
     *          methods and put into private ones.
     *
     */

    mapping cache;
    int ttl;
    float reqs;
    float hits;

    /*
     * Constructor
     * -----------
     * This creates the empty mapping for storage, and it also
     * sets the time to live for cached objects either by an int (secs)
     * passed to it when cloned, or by just taking a guess.
     */

    void create ( void|int cache_for ) {
	if ( cache_for != 0 ) {
	    ttl = cache_for;
	} else {
	    ttl = 600;
	}
	cache = ([ ]);
    }

    /*
     * Public methods
     * --------------
     * These are the methods called by external routines, they are used to
     * store, retrieve, and check freshness of the cache.
     * Also, status() is called by the Roxen FS module to place in the config
     * interface.
     * flush() is used by some contob->set* routines to remove objects from
     * the cache, and also by the Roxen FS module if id->pragma[ "no-cache" ]
     */

    void store ( string filepath, string operation, mixed value ) {
	filepath = fix_path( filepath );
	if ( cache[ filepath ] ) {
	    cache[ filepath ] += ([ operation : ([ "value" : value,
						   "timestamp" : time()
						 ]),
				    "hits" : 0
				  ]);
	} else {
	    cache += ([ filepath : ([ operation : ([ "value" : value,
						     "timestamp" : time()
						   ]),
				      "hits" : 0
				    ])
		      ]);
	}
    }

    mixed retrieve( string filepath, string operation ) {
        filepath = fix_path( filepath );
	if ( !cache[ filepath ] ) {
	    return 0;
	} else if ( !cache[ filepath ][ operation ] ) {
	    return 0;
	} else if ( cache[ filepath ][ operation ][ "timestamp" ] < time() - ttl ) {
	    return 0;
	} else {
            cache[ filepath ][ "hits" ]++;
	    return cache[ filepath ][ operation ][ "value" ];
	}
    }

    int have( string filepath, string operation ) {
        filepath = fix_path( filepath );
	reqs++;
	if ( !cache[ filepath ] ) {
	    return 0;
	} else if ( !cache[ filepath ][ operation ] ) {
	    return 0;
	} else if ( cache[ filepath ][ operation ][ "timestamp" ] < time() - ttl ) {
	    return 0;
	} else {
            hits++;
	    return 1;
	}
    }

    void flush( void|string filepath, void|string operation ) {
	if ( filepath ) {
            filepath = fix_path( filepath );
	    if ( operation ) {
		cache[ filepath ] = m_delete( cache[ filepath ], operation );
	    } else {
		cache = m_delete( cache, filepath );
	    }
	} else {
	    cache = ([ ]);
	}
    }

    string status() {
	string table = "";
        string indexname;
	foreach( indices( cache ), indexname ){
	    table +=
		"<tr><td>" +
		indexname +
		"</td><td>" +
		sprintf( "%d", cache[ indexname ][ "hits" ] ) +
		"</td><td>" +
		sprintf( "%d", sizeof( cache[ indexname ] ) -1 ) +
                "</td></tr>\n";
	}
	string hitrate;
	if ( catch ( hitrate = sprintf( "%:2f", hits / reqs * 100 ) + "%" ) ) {
	    return
                "<font size=+1><b>SQL Filesystem Cache Status</b></font><br><br>\n" +
		"<b>Cache Empty</b><br><br>\n";
	}
	return
	    "<font size=+1><b>SQL Filesystem Cache Status</b></font><br><br>\n" +
	    "<b>Number of cached objects:</b> " + sprintf( "%d", sizeof( cache ) ) + "<br>\n" +
	    "<b>Cache hitrate:</b> " + hitrate + "<br>\n" +
	    "<b>Cache TTL:</b> " + sprintf( "%d", ttl ) + "<br>\n" +
	    "<br>\n" +
	    "<table border=1>\n" +
	    "<tr><td colspan=3><font size=+1><b>Cache Contents</b></font></td></tr>\n" +
	    "<tr><td><b>File</b></td><td><b>Hits</b></td><td><b>Buckets used</b></td></tr>\n" +
	    table +
	    "</table>\n" +
	    "<font size=-1>(due to the way the directory parsing module looks for index files it is possible there will be files in the cache that don't exist)<font><br>\n" +
            "<br>\n";
    }

    /*
     * Private methods
     * ---------------
     * These methods are used internally to the class.
     * fix_path() is used by all the public methods to make sure that we
     * don't wind up with cache inconsistencies (ie difference between "narf"
     * and "narf/").
     */

    private string fix_path( string filepath ) {
	if ( filepath == "" ) {
	    filepath = "/";
	}
	if ( filepath[ 0 ] != '/' ) {
	    filepath = "/" + filepath;
	}
	if ( filepath[ -1 ] == '/' ) {
            filepath = filepath[ 0..sizeof( filepath ) - 1 ];
	}
	return filepath;
    }

}
