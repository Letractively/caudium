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

//! This module uses the Caudium Storage API to store data permanently

constant cvs_version = "$Id$";

#ifdef ENABLE_THREADS
  static Thread.Mutex mutex = Thread.Mutex();
#define PRELOCK() object __key
#define LOCK() __key = mutex->lock(1)
#define UNLOCK() destruct(__key);
#else
#define PRELOCK()
#define LOCK()
#define UNLOCK()
#endif

#define EXPIRE_CHECK 300
inherit "helpers";

string namespace;
int disk_usage;
int _hits, _misses;
object storage;

//! Initialise the disk cache and create the neccessary data structures.
//!
//! @param namespace
//! The namespace of this cache. Used to keep objects seperate on disk.
//!
//! @param _path
//! The path in the filesystem of the server to store objects under.
void create( string _namespace, object _storage ) {
  PRELOCK();
  LOCK();
  storage = _storage;
  namespace = _namespace;
  disk_usage = storage->size();
  call_out( expire_cache, EXPIRE_CHECK );
}

//! Store an object on the disk, and it's metadata in RAM.
//!
//! @param meta
//! The cache mapping from cachelib
void store( mapping meta ) {
  PRELOCK();
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
    LOCK();
    string objpath = Stdio.append_path("/", meta->hash, "/object");
    storage->store(objpath, data);
    string metapath = Stdio.append_path("/", meta->hash, "/meta");
    storage->store(metapath, _encode_value(meta));
    disk_usage += meta->size;
    UNLOCK();
    break;
  case "variable":
    if (meta->_program && (__VERSION__ == 7.3) && (__BUILD__ < 51 )) 
      // ***KLUDGE** pike7.3.x where x < 51 segfaults when decoding a program.
      break;
    if ( meta->disk_cache ) {
      if ( catch( data = _encode_value( meta->object ) ) )
        break;
      meta->size = sizeof( data );
      m_delete( meta, "object" );
      LOCK();
      string objpath = Stdio.append_path("/", meta->hash, "/object");
      storage->store(objpath, data);
      string metapath = Stdio.append_path("/", meta->hash, "/meta");
      storage->store(metapath, _encode_value(meta));
      disk_usage += meta->size;
      UNLOCK();
    }
    break;
  case "image":
    if ( meta->disk_cache ) {
      string data = Image.PNM.encode( meta->object );
      meta->size = sizeof( data );
      m_delete( meta, "object" );
      LOCK();
      string objpath = Stdio.append_path("/", meta->hash, "/object");
      storage->store(objpath, data);
      string metapath = Stdio.append_path("/", meta->hash, "/meta");
      storage->store(metapath, _encode_value(meta));
      disk_usage += meta->size;
      UNLOCK();
    }
    break;
  default:
#ifdef CACHE_DEBUG
    write( "DISK_CACHE( " + namespace + " ): Unknown object type: " + meta->type + ", discarding.\n" );
#endif
    break;
  }
}

//! Retrieve an object from the disk.
//! Scan the metadata for a mathing object, and then retrieve the object
//! off the disk and return it.
//!
//! @param name
//! The name of the object to be retrieved.
void|mixed retrieve(string name, void|int object_only) {
  string hash = get_hash(name);
  PRELOCK();
  LOCK();
  string data = storage->retrieve(Stdio.append_path("/", hash, "/object"));
  mapping meta = storage->retrieve(Stdio.append_path("/", hash, "/meta"));
  if (mappingp(meta)) {
    meta->hits++;
    meta->last_retrieval = time();
    _hits++;
    mapping newmeta = meta;
    if (meta->type == "stdio") {
      meta->object = data;
    }
    else if (meta->type == "variable") {
      meta->object = _decode_value(data);
      if (meta->_program)
       if (catch((program)meta->object)) {
        // This is a test just incase the object has been encoded with a broken codec (eg pike 7.3)
	 UNLOCK();
         refresh(hash);
         return 0;
        }
      else if (meta->type == "image")
        meta->object = Image.PNM.decode(data);
      if ( ! meta->object ) {
        refresh( name );
	return 0;
      }
      storage->store(Stdio.append_path("/", newmeta->hash, "/meta"), _encode_value(newmeta));
      if (object_only)
        return meta->object;
      return meta;
    }
  }
  _misses++;
  return 0;
}

//! Remove an object from the disk cache, if it exists.
//!
//! @param name
//! The name of the object to remove.
void refresh(string name) {
  PRELOCK();
  LOCK();
  storage->unlink(get_hash(name));
}

//! Flush the cache.
//!
//! @param regexp
//! A regular expression used to selectively remove matching objects.
void flush( void|string regexp ) {
  PRELOCK();
  if ( regexp ) {
    LOCK();
    storage->unlink_regexp(regexp);
    return;
  }
  // flush the cache.
  LOCK();
  disk_usage = 0;
  storage->unlink();
}

//! Return the amount of disk space being occupied by the cache.
int usage() {
  PRELOCK();
  LOCK();
  return disk_usage;
}

//! Write all metadata to the disk so that we can get it all back on restart.
//! Then remove the metadata from RAM and shut down.
void stop() {
#ifdef CACHE_DEBUG
  write("DISK_CACHE: Shutting down (%s)\n", namespace);
#endif
  PRELOCK();
  LOCK();
  storage->stop();
#ifdef CACHE_DEBUG
  write("DISK_CACHE: All done.\n");
#endif
}

//! Free n bytes of disk space by forcing an expire then removing objects
//! with the lowest hitrate.
void free( int n ) {
  PRELOCK();
  LOCK();
  int _usage = disk_usage;
  UNLOCK();
  expire_cache( 1 );
  LOCK();
  if ( _usage - disk_usage > n ) {
    return 0;
  }
  int freed;
  array _hash = ({ });
  array _hitrate = ({ });
  foreach(storage->list(), string fname) {
    array tmp = (fname / "/") - ({""});
    if (tmp[1]=="meta")
      continue;
    string hash = tmp[0];
    mapping meta = _decode_value(storage->retrieve(Stdio.append_path("/", hash, "/meta")));
    _hash += ({ hash });
    _hitrate += ({ (float)meta->hits / (float)( time() - meta->create_time ) });
  }
  sort( _hitrate, _hash );
  foreach( _hash, string hash ) {
    if ( freed >= n ) {
      break;
    }
    mapping meta = _decode_value(storage->retrieve(Stdio.append_path("/", hash, "/meta")));
    freed += meta->size;
    disk_usage -= meta->size;
    storage->unlink(Stdio.append_path("/", hash, "/object"));
    storage->unlink(Stdio.append_path("/", hash, "/meta"));
  }
}

//! Remove objects from the cache that have expired.
//!
//! @param nocallout
//! Optionally dont schedule a callout to expire_cache();
void expire_cache( void|int nocallout ) {
  PRELOCK();
#ifdef CACHE_DEBUG
  write( "DISK_CACHE::expire_cache() called.\n" );
#endif
  LOCK();
  foreach(storage->list(), string fname) {
    if ((fname / "/")[2] == "meta")
      continue;
    string hash = (fname / "/")[1];
    mapping meta = _decode_value(storage->retrieve(Stdio.append_path("/", hash, "/meta")));
    if ( meta->expires == -1 ) {
      continue;
    }
    if ( meta->expires <= time() ) {
      disk_usage -= meta->size;
#ifdef CACHE_DEBUG
      write( "Object Expired: %s, expiry: %d, removing from disk.\n", meta->name, meta->expires );
#endif
      storage->unlink(Stdio.append_path("/", hash, "/object"));
      storage->unlink(Stdio.append_path("/", hash, "/meta"));
    }
  }
  if ( ! nocallout ) {
    call_out( expire_cache, EXPIRE_CHECK );
  }
}

//! Return the total number of hits against this cache.
int hits() {
  PRELOCK();
  LOCK();
  return _hits;
}

//! Return the total number of misses against this cache.
int misses() {
  PRELOCK();
  LOCK();
  return _misses;
}

//! Return the total number of objects in this cache.
int object_count() {
  PRELOCK();
  LOCK();
  return sizeof(storage->list()) / 2;
}

//! Private method to encode to bytecode.
//!
//! @param var
//! The pike datatype being encoded.
static string _encode_value( mixed var ) {
  return MIME.encode_base64( encode_value( var, master()->Codec() ), 1 );
}

//! Private method to decode from bytecode.
//!
//! @param data
//! The encoded data.
mixed _decode_value( string data ) {
  mixed obj;
  if ( catch( obj =  decode_value( MIME.decode_base64( data ), master()->Codec() ) ) ) {
    return 0;
  }
  return obj;
}
