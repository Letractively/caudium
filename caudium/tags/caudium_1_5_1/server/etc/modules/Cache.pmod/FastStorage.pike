/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
 * The Cache module and the accompanying code is Copyright © 2002 James Tyson.
 * This code is released under the GPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   James Tyson	<jnt@caudium.net>
 *
 */

//! This the the RAM cache, basically.

constant cvs_version = "$Id$";

#define EXPIRE_CHECK 300
inherit "helpers";

mapping thecache;
string namespace;
mixed disk_cache;
int ram_usage;
int _hits, _misses;

//! Initialise the cache, create the internal data structures that we need.
//!
//! @param _namespace
//! The namespace of the cache.
//!
//! @param _disk_cache
//! Optional copy of the slow storage object, for moving non-expired objects
//! to slow storage when shutting down, or when freeing ram.
void create( string _namespace, void|object _disk_cache ) {
  namespace = _namespace;
  thecache = ([ ]);
  if ( _disk_cache ) {
    disk_cache = _disk_cache;
  } else {
    disk_cache = 0;
  }
  call_out( expire_cache, EXPIRE_CHECK );
}

//! Store an object in the RAM cache, which is just a mapping anyway, but
//! there is no need for the client to know that :)
//!
//! @param meta
//! The mapping created by one of the functions in cachelib
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
    ram_usage += (meta->size?meta->size:0);
    thecache += ([ meta->hash : meta ]);
    break;
  case "image":
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

//! Retrieve the object from the RAM cache, and return it.
//!
//! @param name
//! Name of the object
//!
//! @param object_only
//! Optional argument specifying whether to return the entire object + metadata
//! or just the object itself.
void|mixed retrieve( string name, void|int object_only ) {
  string hash = get_hash( name );
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

//! If the object is a Stdio.File object, then this method is called by
//! retrieve to create a new Stdio.File object, and pipe the data into
//! it, in order to make it appear the same as it was.
//!
//! @param hash
//! The hash that is used to uniquely identify the object.
private mixed get_stdio( string hash ) {
  mapping tmp = thecache[ hash ] + ([ ]);
  string data = tmp->object;
#if constant(Stdio.FakeFile)
  tmp->object = Stdio.FakeFile(data);
#else
  tmp->object = Stdio.File();
  object p = tmp->object->pipe();
  p->set_nonblocking();
  p->write( data );
  p->close();
#endif
  return tmp;
}

//! Force the removal of an object from the RAM cache.
//!
//! @param name
//! The name of the object.
void refresh( string name ) {
  string hash = get_hash( name );
  if (thecache[ hash ]) {
    ram_usage -= thecache[ hash ]->size;
    m_delete( thecache, hash );
  }
}

//! Flush objects from the RAM cache.
//!
//! @param regexp
//! Optional regular expression used to selectively delete objects from
//! the cache.
void flush( void|string regexp ) {
  if ( regexp ) {
    // Just flush some of the cache.
    object r = Regexp( regexp );
    foreach( indices( thecache ), string key ) {
      if ( r->match( key ) ) {
#ifdef CACHE_DEBUG
        write( "RAM_CACHE: Flushing matching key: " + key + "\n" );
#endif
        refresh( key );
      }
    }
    return;
  }
  // flush the entire ram cache
#ifdef CACHE_DEBUG
  write( "RAM_CACHE: Flushing entire cache.\n" );
#endif
  ram_usage = 0;
  thecache = ([ ]);
}

//! Return the amount of RAM being used by this cache.
int usage() {
  return ram_usage;
}

//! Use the copy of slow storage that we might have to copy everything to
//! slow storage. If we dont have it then there's not much we can do.
//! Just delete it all.
void stop() {
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

//! Deep voodoo magic to remove objects when we need to free some RAM.
//! First, sort the list of objects in the cache in a list of least
//! retrieved (lowest hitrate) to most retrieved (highest hitrate).
//! Then simply remove them one by one until we have removed >= n
//!
//! @param n
//! Remove n bytes worth of objects.
void free( int n ) {
#ifdef CACHE_DEBUG
  write( "RAM_CACHE: Cache asked to reduce RAM usage by " + n + " bytes\n" );
#endif
#ifdef CACHE_DEBUG
  write( "RAM_CACHE: Calling expire_cache()....\n" );
#endif
  int _usage = ram_usage;
  expire_cache( 1 );
  if ( _usage - ram_usage > n ) {
#ifdef CACHE_DEBUG
    write( "RAM_CACHE: Expiring the cache freed enough memory to satisfy\n" );
#endif
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
    float hit = (float)thecache[hash]->hits;
    float rate = (float)(time() - thecache[hash]->create_time);
    if (hit && rate)
      _hitrate += ({ hit / rate });
    else
      _hitrate += ({ 0.0 });
  }
  sort( _hitrate, _hash );
#ifdef CACHE_DEBUG
  write( "RAM_CACHE: Freeing objects in order of lowest hitrate.\n" );
#endif
  foreach( _hash, string hash ) {
#ifdef CACHE_DEBUG
    write( "RAM_CACHE: Freeing object " + thecache[ hash ]->name + "\n" );
#endif
    if ( freed >= n ) {
#ifdef CACHE_DEBUG
      write( "RAM_CACHE: RAM free is finished\n" );
#endif
      return;
    }
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

//! Remove expired objects from the RAM cache.
//!
//! @param nocallout
//! Optionally dont schedule a callout to expire_cache()
void expire_cache( void|int nocallout ) {
#ifdef CACHE_DEBUG
  write( "RAM_CACHE::expire_cache() called.\n" );
#endif
  foreach( indices( thecache ), string hash ) {
    if ( thecache[ hash ]->expires == -1 ) {
      continue;
    }
    if ( thecache[ hash ]->expires <= time() ) {
      ram_usage -= thecache[ hash ]->size;
#ifdef CACHE_DEBUG
      write( "Object Expired: %s, expiry: %d, removing from RAM.\n", thecache[ hash ]->name, thecache[ hash ]->expires );
#endif
      m_delete( thecache, hash );
    }
  }
  if ( ! nocallout ) {
    call_out( expire_cache, EXPIRE_CHECK );
  }
}

//! Return the total number of hits against this cache.
int hits() {
  return _hits;
}

//! Return the total number of misses against this cache.
int misses() {
  return _misses;
}

//! Return the total number of objects in this cache.
int object_count() {
  return sizeof( thecache );
}
