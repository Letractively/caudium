/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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


class sqlfs_read {
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
    int atime;

    /*
     * Constructor
     * -----------
     * I want to recieve a database cursor object, a cache object (see class
     * object_cache) and optionally a path.
     */

    void create ( object db_conn, object obj_cache, void|string file_path, int store_atime ) {
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

    int get_mode() {
	if ( !cache->have( path, "mode" ) ) {
	    int content_ID = get_content_ID();
	    string query = "select mode from content, content_info where content_info.ID = content.info_ID and content.ID = " + sprintf( "%d", content_ID );
	    object result;
	    if ( catch( result = db->big_query( query ) ) ) {
		throw( ({ "Unable to retrieve mode from content object", backtrace() }) );
	    }
	    if ( result->num_rows() == 0 ) {
		return 0;
	    }
	    array row;
	    row = result->fetch_row();
            int val;
            sscanf( "%d", row[ 0 ], val );
	    cache->store( path, "mode", val );
            return val;
	} else {
	    return cache->retrieve( path, "mode" );
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
	if ( atime == 1 ) {
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
	}
        cache->store( path, "a_time", time() );
    }

    /* Roxen MODULE_LOCATION API Compatibility
     * ---------------------------------------
     * These shouldnt really be here, but I wanted to keep as much processing
     * as possible away from the module itself.
     */

    void|array find_dir () {
	/* Roxen API Compatibility */
	int content_ID = get_content_ID();
	if ( content_ID != 0 ) {
	    return get_directory_listing();
	}
    }

    void|array stat_file () {
	/* Roxen API Compatibility */
	int content_ID = get_content_ID();
	if ( content_ID != 0 ) {
	    int file_type = get_file_type();
            int mode = get_mode();
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

