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


class sqlfs_write {

    /* THIS IS REALLY BROKEN!!!! */

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
    int uid, gid;

    /*
     * Constructor
     * -----------
     * I want to recieve a database cursor object, a cache object (see class
     * object_cache) and optionally a path.
     */

    void create ( object db_conn, int u, int g ) {
        /* Please pass me a database connection to use */
	db = db_conn;
	uid = u;
        gid = g;
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

    int get_content_ID ( string path ) {
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
    }

    /*
     * "Set" Methods
     * -------------
     * These are for updating data about the content object.
     * These are probably for creating a new piece of content or for updating
     * a pre-existing object.
     */

    void set_atime( string path ) {
	int content_ID = get_content_ID( path );
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

    void set_ctime( string path ) {
	int content_ID = get_content_ID( path );
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

    void set_mtime( string path ) {
	int content_ID = get_content_ID( string path );
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

    void set_uid( string path, int uid ) {
	int content_ID = get_content_ID( string path );
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

    void set_gid( string path, int gid ) {
	int content_ID = get_content_ID( path );
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

    void set_mode( string path, int mode ) {
        /* I expect a string containing something like "r,w,x" */
	int content_ID = get_content_ID( path );
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
	query = "update content_info set mode = " + sprintf( "%d", mode ) + " where ID = " + sprintf( "%d", row[ 0 ] );
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to update object metadata.", backtrace() }) );
	}
        cache->flush( path, "mode" );
    }

    void set_filename( string oldpath, string newpath ) {
	int content_ID = get_content_ID( oldpath );
	if ( content_ID == 0 ) {
	    return;
	}
	string query = "update allocation set filename = '" + mysql_safe( newpath ) + "' where content_ID = " + sprintf( "%d", content_ID );
	object result;
	if ( catch( result = db->big_query( query ) ) ) {
	    throw( ({ "Unable to rename file.", backtrace() }) );
	}
        set_mtime();
	cache->flush( oldpath );
    }

    int set_contents( string path, string data ) {
	int content_ID = get_content_ID( path );
	if ( content_ID == 0 ) {
	    return 1;
	}
        // Have to do a select from content to find out the object_ID and update the object.
    }

    int mkdir( string path, void|int mode ) {
	array dirs = path / "/" - ({""});
        string dirpart;
        string tmp = "";
	foreach( dirs, dirpart ) {
            tmp += "/" + dirpart;
	    if ( get_content_ID( tmp ) < 1) {
		return 0; // No such file or directory! (one or more of the parent directories doesnt exist)
	    }
	}
        string p_dir = dirs[ 0..sizeof( dirs ) -2 ] * "/";
	int p_dir_ID = get_content_ID( p_dir );
	object result;
        mixed err;
        array row;
	if ( err = catch( result = db->big_query( "insert into content_info values (NULL, now(), now(), now(), " + sprintf( "%d", uid ) + ", " + sprintf( "%d", gid ) + ", " + sprintf( "%d", mode ) + " )" ) ) ) {
	    throw( ({ "Unable to create directory.", err }) );
	}
	if ( err = catch( result = db->big_query( "select last_insert_id() from content_info" ) ) ) {
	    throw( ({ "Unable to create directory.", err }) );
	}
	row = result->fetch_row();
	int content_info_ID;
	sscanf( "%d", row[ 0 ], content_info_ID );
	if ( err = catch( result = db->big_query( "insert into content values (NULL, " + sprintf( "%d", content_info_ID ) + ", NULL, 'd')" ) ) ) {
	    throw( ({ "Unable to create directory.", err }) );
	}
	if ( err = catch( result = db->big_query( "select last_insert_id() from content" ) ) ) {
	    throw( ({ "Unable to create durectory.", err }) );
	}
	int content_ID;
	row = result->fetch_row();
        sscanf( "%d", row[ 0 ], content_ID );
	if ( err = catch( result = db->big_query( "insert into allocation values (NULL, " + sprintf( "%d", p_dir_ID ) + ", '" + mysql_safe( dirs[ sizeof( dirs ) ] ) + "', " + sprintf( "%d", content_ID ) + " )" ) ) ) {
	    throw( ({ "Unable to create directory.", err }) );
	}
        return 1;
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

}
