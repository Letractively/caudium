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

//! This module is a high level cache object, it handles the storing of objects
//! in fast storage and slow storage, moving objects between storage methods
//! and expiring objects.
//! This is really the brains of the cache. If that's the case why is it
//! so messy? Dont ask me.

constant cvs_version = "$Id$";

object ram_cache;
object disk_cache;
string namespace;
int max_object_ram;
int max_object_disk;
int default_ttl;
int last_access;
string _cache_desc;
mapping behavior_m = ([ ]);

//! Initiate a new cache, this means creating a Cache.FastStorage object to
//! store objects in RAM, and a Cache.SlowStorage.* object to store objects
//! in permantent storage.
//!
//! @param _namespace
//! This is our namespace, ie, our name.
//!
//! @param _max_object_ram
//! Maximum size of an object before it is too big to be stored in RAM
//!
//! @param _max_object_disk
//! Maximum size of an object before it is too big to be stored in SlowStorage
//! i.e. it will always be a cache miss.
//!
//! @param dcache
//! A copy of the SlowStorage method
//!
//! @param _default_ttl
//! This is the time in seconds to keep an object before expiring, unless
//! otherwise specified.
//!
//! @note
//! SlowStorage is a bit of a hack - at this stage disk storage is the only
//! supported backend, and this is hacked in as a constant. This needs to be
//! changed to support a pluggable method.
void create( string _namespace, int _max_object_ram, int _max_object_disk, object dcache, int _default_ttl ) {
  namespace = _namespace;
  max_object_ram = _max_object_ram;
  max_object_disk = _max_object_disk;
  default_ttl = _default_ttl;
  disk_cache = Cache.SlowStorage(namespace, dcache);

  ram_cache = Cache.FastStorage(namespace, disk_cache);
}

//! Change the size options that were set upon creation.
//! 
//! @param _max_object_ram
//! The maximum size an object can be before an object is too big to be stored
//! in RAM.
//!
//! @param _max_object_disk
//! The maximum size an object can be before an object is too big to be stored
//! in slow storage. ie. a cache miss. always.
void set_sizes( int _max_object_ram, int _max_object_disk ) {
  max_object_ram = _max_object_ram;
  max_object_disk = _max_object_disk;
}

//! Override the default TTL for the cache.
//!
//! @param _default_ttl
//! The default time in seconds that the cache will hold onto an object before
//! it's considered stale and must be expunged.
void set_default_ttl( int _default_ttl ) {
  default_ttl = _default_ttl;
}

//! Returns the RAM usage of this cache, in bytes.
int ram_usage() {
  return ram_cache->usage();
}

//! Returns the slow storage usage of this cache, in bytes.
int disk_usage() {
  return disk_cache->usage();
}

//! Magic up some numbers for a status display.
mapping status() {
  int ram_hitrate;
  int disk_hitrate;
  int total_hitrate;
  if ( ram_cache->misses() ) {
    ram_hitrate = (int)(ram_cache->hits() / ram_cache->misses() * 100);
  }
  if ( disk_cache->misses() ) {
    disk_hitrate = (int)(disk_cache->hits() / ram_cache->misses() * 100);
  }
  total_hitrate = ram_hitrate + disk_hitrate / 2;
  return ([
    "fast_hits" : ram_cache->hits(),
    "fast_misses" : ram_cache->misses(),
    "fast_object_count" : ram_cache->object_count(),
    "slow_hits" : disk_cache->hits(),
    "slow_misses" : disk_cache->misses(),
    "slow_object_count" : disk_cache->object_count(),
    "total_hits" : ram_cache->hits() + disk_cache->hits(),
    "total_misses" : disk_cache->misses() + disk_cache->misses(),
    "total_object_count" : ram_cache->object_count() + disk_cache->object_count(),
    "ram_hitrate" : ram_hitrate,
    "disk_hitrate" : disk_hitrate,
    "total_hitrate" : total_hitrate
  ]);
}

//! Store an object in the cache if we can.
//! First, check to see if the object is too big for RAM, if it's not then
//! call store() on the ram storage object, else check to see whether it's
//! too big for slow storage, if it's not then call store() on the slow storage
//! object, otherwise just ignore it and force a cache miss on this object
//! for all eternity (or until the size constraints are lifted).
//!
//! @param cache_response
//! A mapping created by the methods in cachelib.
void store(mapping cache_response) {
#ifdef CACHE_DEBUG
  string _obj = sprintf("%O", cache_response->object);
  if (sizeof(_obj) > 100) {
    _obj = _obj[1..100];
  }
  if (!stringp(_obj)) 
    write("CACHE: store(\"%s\", \"%s\", %s)\n",
          namespace, cache_response->name, _obj);
  else if (sizeof(_obj) < 100)
    write("CACHE: store(\"%s\", \"%s\", %s)\n",
          namespace, cache_response->name, _obj);
  else
    write("CACHE: store(\"%s\", \"%s\", %s)\n",
          namespace, cache_response->name, _obj[0..100]);
#endif
  if (!cache_response->expires)
    cache_response->expires = time() + default_ttl;
  cache_response + behavior_m;
  last_access = time();
  if (cache_response->size > max_object_ram) {
    //if (cache_response->disk_cache) {
      if (cache_response->size > max_object_disk) {
        return 0;
      }
      disk_cache->store(cache_response);
      return 0;
    //}
  }
  ram_cache->store(cache_response);
}

//! Copy from one file descriptior to another, and store it in the cache
//! at the same time.
//! For example, tie a file on the filesystem to id->my_fd and also cache
//! it on the way through.
//!
//! @param name
//! The name of the object which we are going to store.
//!
//! @param in
//! The Stdio.File() object which we're reading from.
//!
//! @param out
//! The Stdio.File() object which we're writing to.
//!
//! @param ext
//! The optional expiry time for the cached data.
void store_async(string name, object in, object out, void|int exp) {
  Cache.Async.Store(store, name, in, out, exp);
}

//! Retrieve an object from the cache.
//! First search the RAM cache for the object, if it's there then return it
//! to the client.
//! If it's not, check the slow storage cache, if it's there then copy it
//! to the RAM cache and remove it from the slow storage cache (if it's not
//! too big, otherwise leave it there), return it to the client.
//! If there is no matching object in either cache then check to see whether
//! we have a valid callback to get the object, if so call it with it's
//! arguments and return it's value. NOTE: This method does not store the
//! result, it relies on the callback to call store() on the cache.
//! **watch out for deadlocks**
//!
//! @param name
//! The name of the object we want to retrieve.
//!
//! @param get_callback
//! Optional callback to the original caller to retrieve the object in the
//! event of a cache miss.
//!
//! @param cb_args
//! Optional array of arguments to pass to get_callback when it's called.
void|mapping retrieve(string name, void|function get_callback, void|array cb_args) {
#ifdef CACHE_DEBUG
  write(sprintf("CACHE: retrieve(\"%s\",\"%s\") -> ", namespace, name));
#endif
  last_access = time();
  mixed _object = ram_cache->retrieve(name);
  if (mappingp(_object)) {
#ifdef CACHE_DEBUG
  write("Hit (FastStorage)\n");
#endif
    return _object->object;
  }
  _object = disk_cache->retrieve(name);
  if (mappingp(_object)) {
#ifdef CACHE_DEBUG
  write("Hit (SlowStorage)\n");
#endif
    if (_object->size < max_object_ram) {
      ram_cache->store(_object);
      disk_cache->refresh(name);
    }
    return _object->object;
  }
#ifdef CACHE_DEBUG
  write("Miss");
#endif
  if (get_callback && functionp(get_callback)) {
#ifdef CACHE_DEBUG
    write(" - calling callback.");
#endif
    return get_callback(@cb_args);
  }
#ifdef CACHE_DEBUG
  write("\n");
#endif
}

//! Asynchonously retrieve an object from the cache and send it to an
//! open Stdio.File() object.
//!
//! @param name
//! The name of the object we want to retrieve it from the cache.
//!
//! @param out
//! The open Stdio.File() object to send the output to.
void|int retrieve_async(string name, object out) {
  mapping m = retrieve(name);
  object obj = m->object;
  if (!objectp(obj))
    return 0;
  if (!obj->set_id)
    return 0;
  Cache.Async.Retrieve(retrieve, name, out);
  return 1;
}

//! Force an object to be deleted from the cache.
//!
//! @param name
//! The name of the object to be removed.
void refresh(string name) {
#ifdef CACHE_DEBUG
  write(sprintf("CACHE: cache_remove(\"%s\",\"%O\")\n", namespace, name));
#endif
  last_access = time();
  ram_cache->refresh(name);
  disk_cache->refresh(name);
}

//! Force the cache to free a certain amount of RAM
//!
//! @param nbytes
//! Remove nbytes of RAM.
void free_ram(int nbytes) {
#ifdef CACHE_DEBUG
  write("RAM_CACHE( " + namespace + " ): Freeing " + nbytes + " RAM\n");
#endif
  ram_cache->free(nbytes);
}

//! Force the cache to free a certain amount of slow storage
//!
//! @param nbytes
//! Remove nbytes of slow storage.
void free_disk(int nbytes) {
  disk_cache->free(nbytes);
}

//! Flush the cache
//!
//! @param regexp
//! Optional regular expression to use when looking for objects to delete from
//! the cahce, otherwise just delete everything.
void flush(void|string regexp) {
#ifdef CACHE_DEBUG
  write("CACHE: Flushing cache" + (regexp?" with regexp":"") + ".\n");
#endif
  last_access = time();
  ram_cache->flush(regexp);
  disk_cache->flush(regexp);
}

//! Stop the cache, write everything out to slow storage and shutdown.
void stop() {
	// Save the state of the cache
#ifdef CACHE_DEBUG
  write("[" + namespace + "] ");
#endif
  ram_cache->stop();
  disk_cache->stop();
}

//! Get or set the description of this cache
//!
//! @param desc
//! Optional description for the cache.
void|string cache_description(void|string desc) {
  if (desc) {
    _cache_desc = desc;
    return 0;
  }
  return _cache_desc;
}

//! Override the default storage behavior of this cache.
//!
//! @param behavior
//! If 0 then keep default behavior. If 1 then use only RAM cache.
//! If 2 then use only disk cache.
void behavior(void|int(0..2) _behavior) {
  switch(_behavior) {
  case 0:
    behavior_m = ([ ]);
    break;
  case 1:
    behavior_m = ([ "disk_cache" : 0 ]);
    break;
  case 2:
    behavior_m = ([ "ram_cache" : 0 ]);
    break;
  }
}
