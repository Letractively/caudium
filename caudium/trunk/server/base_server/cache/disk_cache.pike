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


constant cvs_version = "$Id$";

#define EXPIRE_CHECK 300
inherit "cache_helpers";

mapping thecache;
string namespace;
string path;
string cache_path;
int disk_usage;
int _hits, _misses;

void create( string _namespace, string _path ) {
  namespace = _namespace;
  path = _path;
  cache_path = Stdio.append_path( path, get_hash( version() ), get_hash( namespace ) );
  thecache = get_index();
  call_out( expire_cache, EXPIRE_CHECK );
}

mapping get_index() {
  if ( Stdio.is_dir( cache_path ) ) {
	// Excellent. We already should have data in the cache.
    array dirs = get_dir( cache_path );
    if ( sizeof( dirs ) > 0 ) {
      mapping thecache = ([ ]);
      foreach( dirs, string dirname ) {
        object metadata;
        if (! catch(  metadata = Stdio.File( Stdio.append_path( cache_path, dirname, "meta" ), "r" ) ) ) {
          string m = metadata->read();
          metadata->close();
          mapping meta = _decode_value( m );
#ifdef CACHE_DEBUG
          write( "DISK_CACHE: get_index %O\n", meta );
#endif
          thecache += ([ dirname : meta ]);
          disk_usage += meta->size;
          rm( Stdio.append_path( cache_path, dirname, "meta" ) );
        }
      }
      return thecache;
    } else {
      return ([ ]);
    }
  } else {
	// Initialise a new cache.
    if ( Stdio.mkdirhier( cache_path ) ) {
      return ([ ]);
    } else {
      throw( ({ "Error: Unable to create cache directory for: " + namespace, backtrace() }) );
    }
  }
}

void store( mapping meta ) {
  meta->create_time = (meta->create_time?meta->create_time:time());
  meta->last_retrieval = (meta->last_retrieval?meta->last_retrieval:0);
  meta->hits = (meta->hits?meta->hits:0);
  meta->hash = (meta->hash?meta->hash:get_hash( meta->name ));
  switch( meta->type ) {
  case "stdio":
	// I would like to use nbio for this. Caudium.nbio maybe??
    string data = meta->object->read();
    meta->object->close();
    meta->size = sizeof( data );
    m_delete( meta, "object" );
    if ( Stdio.mkdirhier( Stdio.append_path( cache_path, meta->hash ) ) ) {
      object f = Stdio.File( Stdio.append_path( cache_path, meta->hash, "object" ), "cw" );
      f->write( data );
      f->close();
      disk_usage += meta->size;
      thecache += ([ meta->hash : meta ]);
    }
    break;
  case "variable":
    if ( meta->disk_cache ) {
      if ( catch( data = _encode_value( meta->object ) ) ) {
        break;
      }
      meta->size = sizeof( data );
      m_delete( meta, "object" );
      if ( Stdio.mkdirhier( Stdio.append_path( cache_path, meta->hash ) ) ) {
        object f = Stdio.File( Stdio.append_path( cache_path, meta->hash, "object" ), "cw" );
        f->write( data );
        f->close();
        disk_usage += meta->size;
        thecache += ([ meta->hash : meta ]);
      }
    }
    break;
  case "image":
    if ( meta->disk_cache ) {
      string data = Image.PNM.encode( meta->object );
      meta->size = sizeof( data );
      m_delete( meta, "object" );
      if ( Stdio.mkdirhier( Stdio.append_path( cache_path, meta->hash ) ) ) {
        object f = Stdio.File( Stdio.append_path( cache_path, meta->hash, "object" ), "cw" );
        f->write( data );
        f->close();
        disk_usage += meta->size;
        thecache += ([ meta->hash : meta ]);
      }
    }
    break;
  default:
#ifdef CACHE_DEBUG
    write( "DISK_CACHE( " + namespace + " ): Unknown object type: " + meta->type + ", discarding.\n" );
#endif
    break;
  }
}

void|mixed retrieve( string name, void|int object_only ) {
	// Search the metadata for the object, if we have it then
	// open a file handle to the file and return it.
	// Else return 0.
  string hash = get_hash( name );
	// search for the hash in thecache and return it. This could be tricky.
  if ( thecache[ hash ] ) {
    thecache[ hash ]->hits++;
    thecache[ hash ]->last_retrieval = time();
    _hits++;
    string object_path = Stdio.append_path( cache_path, hash, "object" );
    if ( Stdio.exist( object_path ) ) {
      mapping meta = thecache[ hash ] + ([ ]);
      if ( meta->type == "stdio" ) {
        meta->object = Stdio.File( object_path, "r" );
      } else if ( meta->type == "variable" ) {
        meta->object = _decode_value( Stdio.File( object_path, "r" )->read() );
      } else if ( meta->type == "image" ) {
        meta->object = Image.PNM.decode( Stdio.File( object_path, "r" )->read() );
      }
      if ( object_only ) {
        return meta->object;
      }
      return meta;
    }
  }
  _misses++;
  return 0;
}

void refresh( string name ) {
	// remove the object from cache.
  string hash = get_hash( name );
  if (thecache[ hash ]) {
    disk_usage -= thecache[ hash ]->size;
    m_delete( thecache, hash );
    Stdio.recursive_rm( Stdio.append_path( cache_path, hash ) );
  }
}

void flush( void|string regexp ) {
  if ( regexp ) {
    // Just flush some of the cache.
    object r = Regexp( regexp );
    foreach( indices( thecache ), string key ) {
      if ( r->match( key ) ) {
#ifdef CACHE_DEBUG
        write( "DISK_CACHE: Flushing matching key: " + key + "\n" );
#endif
        refresh( key );
      }
    }
    return;
  }
  // flush the cache.
  thecache= ([ ]);
  disk_usage = 0;
  Stdio.recursive_rm( cache_path );
  Stdio.mkdirhier( cache_path );
}

int usage() {
  return disk_usage;
}

void stop() {
	// Write all the metadata to disk so that we can have some content
	// when it's time to come back.
#ifdef CACHE_DEBUG
  write( "DISK_CACHE: Destroy() called, writing metadata to disk..\n" );
  write( sprintf( "%O\n", thecache ) );
#endif
  foreach( indices( thecache ), string hash ) {
#ifdef CACHE_DEBUG
    write( "DISK_CACHE: Writing metadata about " + thecache[ hash ]->name + " to " + Stdio.append_path( cache_path,hash,"meta" ) + "\n" );
#endif
    string metapath = Stdio.append_path( cache_path, hash, "meta" );
    object metafile = Stdio.File( metapath, "cw" );
    metafile->write( _encode_value( thecache[ hash ] ) );
    metafile->close();
  }
#ifdef CACHE_DEBUG
  write( "DISK_CACHE: All done.\n" );
#endif
}

void free( int n ) {
	// sort the objects in the cache into a list of the least retrieved
	// objects since the last time free was called, then simply vape
	// them one by one until the memory limit is satisfied.
	// free() doesn't have to be particularly complex because either
	// the object isn't worth caching, or it will be on the disk.
	// how it get's in the disk however, is a fairly interesting story.
	// basically, once free has gotten rid of all the crap objects in
	// the cache then it searches for anything that has a hitrate of less
	// than the average hitrate or anything that is larger than the
	// average size and moves it to the disk_cache. this is about the
	// best way I can figure it, but I am reading lots of whitepapers
	// about caching.

	// First: remove expired objects so that we don't double handle.
  int _usage = disk_usage;
  expire_cache( 1 );
	// Second: check to see if the cache is now n bytes smaller.
  if ( _usage - disk_usage > n ) {
	// our work here is done.
    return 0;
  }
  int freed;
  array _hash = ({ });
  array _hitrate = ({ });
  foreach( indices( thecache ), string hash ) {
    _hash += ({ hash });
    _hitrate += ({ (float)thecache[ hash ]->hits / (float)( time() - thecache[ hash ]->create_time ) });
  }
  sort( _hitrate, _hash );
	// Okay, that nastylooking thing was creating arrays of hitrate and the
	// mapping index for thecache so that we can sort them into a list
	// of objects with the lowest hitrate.
  foreach( _hash, string hash ) {
	// Step through the list, in order of lowest hitrate to highest.
    if ( freed >= n ) {
	// If we have freed enough memory then yay!
      break;
    }
	// Before removing the object, check to see if you can stick it
	// on the disk.
    freed += thecache[ hash ]->size;
    disk_usage -= thecache[ hash ]->size;
    m_delete( thecache, hash );
    Stdio.recursive_rm( Stdio.append_path( cache_path, hash ) );
  }
}

void expire_cache( void|int nocallout ) {
#ifdef CACHE_DEBUG
  write( "DISK_CACHE::expire_cache() called.\n" );
#endif
    // Remove expired objects.
  foreach( indices( thecache ), string hash ) {
    if ( thecache[ hash ]->expires == -1 ) {
      continue;
    }
    if ( thecache[ hash ]->expires <= time() ) {
      disk_usage -= thecache[ hash ]->size;
#ifdef CACHE_DEBUG
      write( "Object Expired: %s, expiry: %d, removing from disk.\n", thecache[ hash ]->name, thecache[ hash ]->expires );
#endif
      m_delete( thecache, hash );
      Stdio.recursive_rm( Stdio.append_path( cache_path, hash ) );
    }
  }
  if ( ! nocallout ) {
    call_out( expire_cache, EXPIRE_CHECK );
  }
}

int hits() {
  return _hits;
}

int misses() {
  return _misses;
}

int object_count() {
  return sizeof( thecache );
}

string _encode_value( mixed var ) {
  return MIME.encode_base64( encode_value( var, master()->Codec() ) );
}

mixed _decode_value( string data ) {
  mixed obj;
  if ( catch( obj =  decode_value( MIME.decode_base64( data ), master()->Codec() ) ) ) {
    return 0;
  }
  return obj;
}
