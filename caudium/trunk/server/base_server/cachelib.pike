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

//function get_cache = caudium->cache_manager->get_cache;

#define DEFAULT_TTL 600
// Stupid arbitary number. 10 minutes.

private mapping go( string type, mixed obj, string name, void|int exp ) {
  mapping meta = ([ ]);
  meta->name = name;
  meta->object = obj;
  switch (exp) {
  case -1:
    meta->expires = -1;
    break;
  case 0:
    meta->expires = time() + DEFAULT_TTL;
    break;
  default:
    if ( ( exp < time() ) && ( exp > 0 ) ) {
      meta->expires = exp + time();
    } else if ( exp > time() ) {
      meta->expires = exp;
    }
    break;
  }
#ifdef CACHE_DEBUG
  write( "setting expiry to: %d\n", meta->expires );
#endif
  switch (type) {
  case "file":
    meta->size = obj->stat()[ 1 ];
    meta->type = "stdio";
    meta->ram_cache = 1;
    meta->disk_cache = 1;
    meta->_file = 1;
    break;
  case "pike":
    meta->size = 0;
    meta->type = "variable";
    meta->ram_cache = 1;
    meta->disk_cache = 1;
    switch (sprintf( "%t", meta->object)) {
    case "int":
      meta->_int = 1;
      break;
    case "array":
      meta->_array = 1;
      break;
    case "multiset":
      meta->_multiset = 1;
      break;
    case "mapping":
      meta->_mapping = 1;
      break;
    case "object":
      meta->_object = 1;
      meta->disk_cache = 0;
      break;
    case "function":
      meta->_function = 1;
      meta->disk_cache = 0;
      break;
    case "program":
      meta->_program = 1;
      break;
    }
    break;
  case "program":
    meta->size = 0;
    meta->type = "variable";
    meta->ram_cache = 1;
    meta->disk_cache = 1;
    meta->_program = 1;
    break;
  case "string":
    meta->size = sizeof( obj );
    meta->type = "variable";
    meta->ram_cache = 1;
    meta->disk_cache = 1;
    meta->_string = 1;
    break;
  case "image":
    meta->size = sizeof( (string)obj );
    meta->type = "image";
    meta->ram_cache = 1;
    meta->disk_cache = 1;
    meta->_image = 1;
    break;
  }
#ifdef CACHE_DEBUG
  write( "Storing with metadata: %O\n", meta );
#endif
  return meta;
}

function cache_file = cache_file_object;
function cache_http = cache_http_answer;
function cache_pike = cache_pike_object;
function cache_program = cache_program_object;
function cache_string = cache_string_object;
function cache_image = cache_image_object;

mapping cache_file_object( object file, string name, void|int exp ) {
  return go( "file", file, name, exp );
}

mapping cache_http_answer( mapping http_answer, object id ) {
}

mapping cache_pike_object( mixed var, string name, void|int exp ) {
  return go( "pike", var, name, exp );
}

mapping cache_program_object( program p, string name, void|int exp ) {
  return go( "program", p, name, exp );
}

mapping cache_string_object( string s, string name, void|int exp) {
  return go( "string", s, name, exp );
}

mapping cache_image_object( object img, string name, void|int exp ) {
  return go( "image", img, name, exp );
}
