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

//! This module implements a wrapper around a real cache which will cause
//! the client script to believe it has a fully functioning cache even if
//! the cache it refers to has been shutdown due to inactivity.

constant cvs_version = "$Id$";

#ifdef ENABLE_THREADS
  static Thread.Mutex mutex = Thread.Mutex();
# define LOCK() object __key = mutex->lock(1)
#else
# define LOCK() 
#endif

object real_cache;
function get_cache;
string namespace;

//! Check that real_cache is actually a Cache.Cache object and not null, if
//! it is then ask the cache manager for a new copy, this will cause the
//! index to be re-read from disk and cloned.
private void restart_cache() {
  LOCK();
  if (! real_cache) {
    real_cache = get_cache(namespace, 1);
  }
}

//! Initiate the Cache.Client with data it needs
//!
//! @param _real_cache
//! a copy of a real cache that we will store data in
//!
//! @param _get_cache
//! a copy of Cache.Manager's get_cache function, so that we can get a new
//! copy of the Cache.Cache if it is no longer there.
//!
//! @param _namespace
//! the namespace we live in.
void create(object _real_cache, function _get_cache, string _namespace) {
  real_cache = _real_cache;
  get_cache = _get_cache;
  namespace = _namespace;
#ifdef CACHE_DEBUG
  write(sprintf("CLIENT_CACHE: Client cache in namespace %O created.\n", namespace));
#endif

}

//! Tell the cache that the maximum object sizes are to be changed.
//! This allows the client script to override system defaults as to how big
//! objects can be. I am undecided as to whether this is a good idea.
//!
//! @param max_object_ram
//! Maximum size for an object before it is too big to be stored in RAM
//!
//! @param max_object_disk
//! Maximum size for an object before it is too big to be stored in slow storage.
void set_sizes(int max_object_ram, int max_object_disk) {
  restart_cache();
  real_cache->set_sizes(max_object_ram, max_object_disk);
}

//! Override the system default time to live of objects in our cache.
//! This, however, is a good idea.
//!
//! @param default_ttl
//! TTL (seconds).
void set_default_ttl(int default_ttl) {
  restart_cache();
  real_cache->set_default_ttl(default_ttl);
}

//! Report how much RAM we're using.
int ram_usage() {
  restart_cache();
  return real_cache->ram_usage();
}

//! Report how much slow storage we're using.
int disk_usage() {
  restart_cache();
  return real_cache->disk_usage();
}

//! Return a mapping of statistics about this cache.
mapping status() {
  restart_cache();
  return real_cache->status();
}

//! Store an object in the cache
//!
//! @param cache_response
//! The output of one of the cache_* methods in cachelib
void store(mapping cache_response) {
  restart_cache();
  real_cache->store(cache_response);
}

//! Store an Stdio.File() object in the cache using non-blocking I/O.
//!
//! @param cache_response
//! The output of one of the cache_* methods in cachelib
void store_async(string name, object in, object out, void|int exp) {
  restart_cache();
  real_cache->store_async(name, in, out, exp);
}

//! Retrieve an object from the cache
//!
//! @param name
//! The name of the object we want to retrieve.
//!
//! @param get_callback
//! Optional callback used to get the object in the event of a cache miss.
//!
//! @param cb_args
//! An array of optional arguments to the callback.
void|mapping retrieve(string name, void|function get_callback, void|array cb_args) {
  restart_cache();
  return real_cache->retrieve(name, get_callback, cb_args);
}

//! Retrieve an object from the cache and write it directly to a Stdio.File
//! object, which is handy for things like http_pipe_in_progress().
//! Returns 1 if the object exists in the cache, and 0 if it's not.
//!
//! @param name
//! The name of the object we want to retrieve.
//!
//! @param out
//! The output file descriptor (Stdio.File()).
void|int retrieve_async(string name, object out) {
  restart_cache();
  return real_cache->retrieve_async(name, out);
}


//! Refresh a specific object (i.e. delete it)
//!
//! @param name
//! Name of the object we want to remove.
void refresh(string name) {
  restart_cache();
  real_cache->refresh(name);
}

//! Make the caches RAM usage smaller.
//!
//! @param nbytes
//! How many bytes smaller the RAM cache needs to be.
void free_ram(int nbytes) {
  restart_cache();
  real_cache->free_ram(nbytes);
}

//! Make the caches slow storage smaller.
//!
//! @param nbytes
//! How many bytes smaller the slow storage needs to be.
void free_disk(int nbytes) {
  restart_cache();
  real_cache->free_disk(nbytes);
}

//! Flush the cache
//!
//! @param regexp
//! Optional regexp to use for selectively deleting objects.
void flush(void|string regexp) {
  restart_cache();
  real_cache->flush(regexp);
}

//! Shut down this cache
void stop() {
  restart_cache();
  real_cache->stop();
}

//! Get or set the description of this cache.
//!
//! @param desc
//! Optional description to set on this cache.
void|string cache_description(void|string desc) {
  restart_cache();
  return real_cache->cache_description(desc);
}

//! Override the default storage behavior of this cache.
//!
//! @param behavior
//! If 0 then keep default behavior. If 1 then use only RAM cache.
//! If 2 then use only disk cache.
void behavior(void|int(0..2) _behavior) {
  restart_cache();
  real_cache->behavior(_behavior);
}
// Language hack
function behaviour = behavior;
