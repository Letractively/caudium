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
mixed disk_cache;
int ram_usage;
int _hits, _misses;

void create( string _namespace, void|object _disk_cache ) {
	// Initialise and pre-allocate the ram cache.
	// disk_cache: This is the disk cache object, we need it so that
	//             we can move stuff in and out of ram when it's too old.
	// max_size: The maximum size of RAM that we're allowed to use.
	// call disk_cache->get_index() to retrieve the metadata about
	// any objects that are on the disk after being stored last time
	// we we're here.
  namespace = _namespace;
  thecache = ([ ]);
  if ( _disk_cache ) {
    disk_cache = _disk_cache;
  } else {
    disk_cache = 0;
  }
  call_out( expire_cache, EXPIRE_CHECK );
}

void store( mapping meta ) {
  meta->create_time = (meta->create_time?meta->create_time:time());
  meta->last_retrieval = (meta->last_retrieval?meta->last_retrieval:0);
  meta->hits = (meta->hits?meta->hits:0);
  meta->hash = (meta->hash?meta->hash:get_hash( meta->name ));
  switch( meta->type ) {
  case "stdio":
	// Use non-blocking IO to move to RAM?
	// At this stage, I can't figure out how to do this nicely, I will
	// sort it out later. In the mean time just read everything.
    object stdio = meta->object;
    meta->object = stdio->read();
    stdio->close();
    meta->size = sizeof( meta->object );
    ram_usage += meta->size;
    thecache += ([ meta->hash : meta ]);
    break;
  case "variable":
	// Use standard blocking to move to ram.
    ram_usage += (meta->size?meta->size:0);
    thecache += ([ meta->hash : meta ]);
    break;
  default:
#ifdef CACHE_DEBUG
    write( "RAM_CACHE( " + namespace + " ): Unknown object type: " + meta->type + ", discarding.\n" );
#endif
    break;
  }
}

void|mixed retrieve( string name, void|int object_only ) {
	// same as cache->retrieve()
	// search the ram_cache, and then the disk_cache index for an object
	// and then return in. If it turns out that we don't have it then 
	// return 0.
	// if it's in the disk_cache then move it back into the ram_cache
	// as long as it's not bigger than the pre-decided limit for 
	// object size. this will be done with a flash bi-directional
	// non-blocking io class, kindof like a proxy for file objects.
  string hash = get_hash( name );
	// search for the hash in thecache and return it. This could be tricky.
  if ( thecache[ hash ] ) {
    thecache[ hash ]->hits++;
    thecache[ hash ]->last_retrieval = time();
    _hits++;
    if ( thecache[ hash ]->type == "stdio" ) {
	// This is a hax to move anything that used to be a stdio.file object
	// back to a new stdio.file object.
      mapping tmp = get_stdio( hash );
      if ( object_only ) {
        return tmp->object;
      }
      return tmp;
    }
    if ( object_only ) {
      return thecache[ hash ]->object;
    }
    return thecache[ hash ];
  }
  _misses++;
  return;
}

private mixed get_stdio( string hash ) {
  mapping tmp = thecache[ hash ] + ([ ]);
  string data = tmp->object;
  tmp->object = Stdio.File();
  object p = tmp->object->pipe();
  p->set_nonblocking();
  p->write( data );
  p->close();
  return tmp;
}

void refresh( string name ) {
	// remove the object from cache.
  string hash = get_hash( name );
  if (thecache[ hash ]) {
    ram_usage -= thecache[ hash ]->size;
    m_delete( thecache, hash );
  }
}

void flush() {
	// flush the entire ram cache.
  ram_usage = 0;
  thecache = ([ ]);
}

int usage() {
  return ram_usage;
}

void stop() {
	// use the standard stuff to move everything to disk_cache
	// cycle through all the data in the ram cache and call
	// disk_cache->store() on it.
	// how do we make destroy() wait until all that's done to make sure
	// the data is written before the object is destroyed?
  if ( objectp( disk_cache ) ) {
#ifdef CACHE_DEBUG
    write( "RAM_CACHE: stop() called, writing contents of cache to disk..\n" );
#endif
    foreach( indices( thecache ), string hash ) {
      if ( thecache[ hash ]->disk_cache ) {
#ifdef CACHE_DEBUG
        write( "RAM_CACHE: Storing object " + thecache[ hash ]->name + " on disk\n" );
#endif
        if ( thecache[ hash ]->type == "stdio" ) {
          disk_cache->store( get_stdio( hash ) );
        } else {
          disk_cache->store( thecache[ hash ] );
        }
      }
    }
#ifdef CACHE_DEBUG
    write( "RAM_CACHE: All done.\n" );
#endif
  }
  flush();
}

void free( int n ) {
#ifdef CACHE_DEBUG
  write( "RAM_CACHE: Cache asked to reduce RAM usage by " + n + " bytes\n" );
#endif
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
#ifdef CACHE_DEBUG
  write( "RAM_CACHE: Calling expire_cache()....\n" );
#endif
  int _usage = ram_usage;
  expire_cache( 1 );
	// Second: check to see if the cache is now n bytes smaller.
  if ( _usage - ram_usage > n ) {
#ifdef CACHE_DEBUG
    write( "RAM_CACHE: Expiring the cache freed enough memory to satisfy\n" );
#endif
	// our work here is done.
    return;
  }
  int freed;
  array _hash = ({ });
  array _hitrate = ({ });
#ifdef CACHE_DEBUG
  write( "RAM_CACHE: Calculating hitrates for objects\n" );
#endif
  foreach( indices( thecache ), string hash ) {
    _hash += ({ hash });
    _hitrate += ({ (float)thecache[ hash ]->hits / (float)( time() - thecache[ hash ]->create_time ) });
  }
  sort( _hitrate, _hash );
	// Okay, that nastylooking thing was creating arrays of hitrate and the
	// mapping index for thecache so that we can sort them into a list
	// of objects with the lowest hitrate.
#ifdef CACHE_DEBUG
  write( "RAM_CACHE: Freeing objects in order of lowest hitrate.\n" );
#endif
  foreach( _hash, string hash ) {
#ifdef CACHE_DEBUG
    write( "RAM_CACHE: Freeing object " + thecache[ hash ]->name + "\n" );
#endif
	// Step through the list, in order of lowest hitrate to highest.
    if ( freed >= n ) {
#ifdef CACHE_DEBUG
      write( "RAM_CACHE: RAM free is finished\n" );
#endif
 	// If we have freed enough memory then yay!
      //break;
      return;
    }
	// Before removing the object, check to see if you can stick it
	// on the disk.
    if ( ( objectp( disk_cache ) ) && ( thecache[ hash ]->disk_cache ) ) {
#ifdef CACHE_DEBUG
      write( "RAM_CACHE: Storing object in disk_cache\n" );
#endif
      mixed obj;
      if ( thecache[ hash ]->type == "stdio" ) {
        obj = get_stdio( hash );
      } else {
        obj = thecache[ hash ];
      }
#ifdef CACHE_DEBUG
      write( sprintf( "%O\n", obj ) );
#endif
      if ( ! zero_type( obj ) ) {
        disk_cache->store( obj );
      }
    }
    freed += thecache[ hash ]->size;
    ram_usage -= thecache[ hash ]->size;
#ifdef CACHE_DEBUG
    write( "RAM_CACHE: Removing object from RAM\n" );
#endif
    m_delete( thecache, hash );
  }
}

void expire_cache( void|int nocallout ) {
#ifdef CACHE_DEBUG
  write( "RAM_CACHE::expire_cache() called.\n" );
#endif
	// Remove expired objects.
  foreach( indices( thecache ), string hash ) {
    if ( thecache[ hash ]->expires == -1 ) {
      continue;
    }
    if ( thecache[ hash ]->expires <= time() ) {
      ram_usage -= thecache[ hash ]->size;
      m_delete( thecache, hash );
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
