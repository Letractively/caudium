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
 * Okay, whenever you want to use the cache you simply need to inherit
 * cachelib and then get hold of your cache object from caudium, this is
 * discussed in the notes for cache_manager.pike.
 * These are used kindof like you use the return functions in caudiumlib
 * (eg http_string_answer()) - whenever you ask the cache to store an
 * object you must do it through these functions to ensure that the
 * required metadata is present for the cache to use.
 *
 * The functions that are available are:
 *
 * mapping cache_file_object( Stdio.File file, string name, void|int exp )
 *  This function is used when you need to store a Stdio.File object in
 *  the cache, you give it the filehandle, a unique identifier (name)
 *  - probably the URI or file path - and then also the expire time,
 *  which can be either in seconds since epoch or seconds from now, also
 *  if you give it -1 then the object will never expire - this is
 *  particularly useful if you want to save rendering time on images or
 *  something similar (I'm using it in the new photo album module).
 *
 * mapping cache_pike_object( mixed var, string name, void|int exp )
 *  cache_pike_object and cache_string_object are almost identical and
 *  will be fleshed out later sometime, however just use cache_pike_object
 *  for the mean time, it stores any kind of pike data structure, however
 *  it doesn't use the disk cache at this time, it will do so in the future.
 *
 */

constant cvs_version = "$Id$";

#define DEFAULT_TTL 300
// Stupid arbitary number.

mapping cache_file_object( object file, string name, void|int exp ) {
	// Use this to store a file to a cache.
	// file: The Stdio.file object that we are working with
	// name: the name of the file.
	// the expiry time of the object, -1 for never.
  if ( ( exp ) && ( exp > 0 ) && ( exp < time() ) ) {
    exp = exp + time();
  }
  return ([
            "object" : file,
            "name" : name,
            "size" : file->stat()[1],
            "expires" : (exp?exp:time() + DEFAULT_TTL),
            "type" : "stdio",
            "ram_cache" : 1,
            "disk_cache" : 1,
            "nbio" : 1,
            "_file" : 1
         ]);
}

mapping cache_pike_object( mixed var, string name, void|int exp ) {
	// Use this to place any kind of pike data structure in cache.
	// var: The pike datatype being stored in RAM.
	// name: the name of the object
	// exp: the expiry time of the object, -1 for never.
  if ( ( exp ) && ( exp > 0 ) && ( exp < time() ) ) {
    exp = exp + time();
  }
  mapping retval = ([
                    "object" : var,
                    "name" : name,
                    "size" : 0,
                    "expires" : (exp?exp:time() + DEFAULT_TTL),
                    "type" : "variable",
                    "ram_cache" : 1,
                    "disk_cache" : 0,
                    "nbio" : 0
                 ]);
  if ( intp( var ) ) {
    retval->_int = 1;
  } else if ( stringp ( var ) ) {
    retval->_string = 1;
    retval->size = sizeof( var );
    retval->disk_cache = 1;
  } else if ( arrayp( var ) ) {
    retval->_array = 1;
    retval->size = sizeof( var * "" );
  } else if ( multisetp( var ) ) {
    retval->_multiset = 1;
    retval->size = sizeof( indices( var ) * "" );
  } else if ( mappingp( var ) ) {
    retval->_mapping = 1;
    retval->size = sizeof( indices( var ) * "" ) + sizeof( values ( var * "" ) );
  } else if ( objectp( var ) ) {
    retval->_object = 1;
    retval->size = sizeof( indices( var ) * "" ) + sizeof( values ( var * "" ) );
  } else if ( functionp( var ) ) {
    retval->_function = 1;
  } else if ( programp( var ) ) {
    retval->_program = 1;
    retval->disk_cache = 1;
  }
  return retval;
}

mapping cache_program_object( program p, string name, void|int exp ) {
  if ( ( exp ) && ( exp > 0 ) && ( exp < time() ) ) {
    exp = exp + time();
  }
  return ([
            "object" : p,
            "name" : name,
            "size" : 0,
            "expires" : (exp?exp:time() + DEFAULT_TTL),
            "type" : "variable",
            "ram_cache" : 1,
            "disk_cache" : 1,
            "nbio" : 0,
            "_program" : 1
          ]);
}

mapping cache_string_object( string s, string name, void|int exp) {
  if ( ( exp ) && ( exp > 0 ) && ( exp < time() ) ) {
    exp = exp + time();
  }
  return ([
            "object" : s,
            "name" : name,
            "size" : sizeof( s ),
            "expires" : (exp?exp:time() + DEFAULT_TTL),
            "type" : "variable",
            "ram_cache" : 1,
            "disk_cache" : 1,
            "nbio" : 0,
            "_string" : 1
          ]);
}
