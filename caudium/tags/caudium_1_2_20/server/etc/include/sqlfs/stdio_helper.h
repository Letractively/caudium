/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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


class Stdio_helper {

    /*
     *
     * This is here to let me hand Caudium a Stdio.File object even when
     * the file doesnt actually exist on the filesystem.
     *
     * This is a complete re-write from the old fake_Stdio() class, and seems
     * to work a whole bunch better.
     * I have tried to make it as compatible as possible with Stdio.File
     * because you never know what those funky Caudium guys will try and
     * do with my file handles!
     * You may notice the addition of __open_read( object o ) and
     * __open_write( object o ) - they have been added so that this object
     * can be as compatible with Stdio.File as possible, right up and down to
     * being able to "open" a file - but it needs the sqlfs read or write
     * object to do stuff with before it can commit anything.
     * Other than that everything seems to be coming together nicely.
     *
     */

    object readobj;
    object writeobj;
    int upto = 0;
    function close_callback;
    mixed file_id;
    function read_callback;
    function write_callback;
    int max_length;

    void create( void|string filename, void|string mode, void|int mask ) {
    }

    int open( string filename, string how, void|int mask ) {
        return 0;
    }

    void __open_read( object robj ) {
	readobj = robj;
        max_length = sizeof( readobj->get_file_contents() );
    }

    void __open_write( object wobj ) {
	writeobj = wobj;
    }

    int close( void|string how ) {
        // Make some Stdio.File compatibility
	if ( close_callback ) {
            close_callback();
	}
	destruct( readobj ); // This is to make damn sure that when it's closed it can't be read from anymore.
        return 1;
    }

    int|array stat() {
	mixed stat = readobj->stat_file();
	if ( arrayp( stat ) ) {
	    return stat;
	} else {
	    return 0;
	}
    }

    int tell() {
	return upto;
    }

    int trunctate( int length ) {
        max_length = length;
	return 1;
    }

    int|string read( void|int nbytes ) {
        // This is the really tricky part.
	string contents;
	mixed data = readobj->get_file_contents();
	if ( intp( data ) ) {
	    return 0;
	} else {
	    contents = data;
	    if ( sizeof( contents ) > max_length ) {
		contents = contents[ 0..max_length ];
	    }
	}
	if ( nbytes > 0 ) {
            // we're doing a partial read.
	    int old_upto = upto;
	    upto = old_upto + nbytes;
	    return contents[ old_upto .. upto ];
	} else {
            int old_upto = upto;
	    upto = sizeof( contents );
            return contents[ old_upto .. upto ];
	}
    }

    int|string read_oob( void|int nbytes ) {
	return 0;
    }

    int seek( int pos ) {
	if ( pos > -1 ) {
	    upto = pos;
	} else {
	    int filesize = readobj->get_file_size();
            upto = filesize - pos;
	}
        return upto;
    }

    int write( string data ) {
        return -1;
    }

    int write_oob ( string data ) {
        return -1;
    }

    int query_fd () {
	return -11;
    }

    function query_close_callback() {
	return close_callback;
    }

    mixed query_id( mixed id ) {
	return id;
    }

    function query_read_callback() {
	return read_callback;
    }

    function query_write_callback() {
	return write_callback;
    }

    void set_blocking() {}

    void set_buffer( void|int buffsize, string mode ) {}

    void set_close_callback( function cc ) {
	close_callback = cc;
    }

    void set_close_on_exec( int onoff ) {}

    void set_id( mixed id ) {
	file_id = id;
    }

    void set_nonblocking( void|function(mixed, string:void) r_callback,
			  void|function(mixed:void) w_callback,
			  void|function(mixed:void) c_callback,
			  void|function(mixed, string:void) r_oob_callback,
			  void|function(mixed:void) w_oob_callback ) {
	if ( r_callback ) { read_callback = r_callback;	}
	if ( w_callback ) { write_callback = w_callback; }
	if ( c_callback ) { close_callback = c_callback; }
        // Ignore OOB??
    }

    void set_read_callback( function r_callback ) {
	read_callback = r_callback;
    }

    void set_write_callback( function w_callback ) {
        write_callback = w_callback;
    }

}
