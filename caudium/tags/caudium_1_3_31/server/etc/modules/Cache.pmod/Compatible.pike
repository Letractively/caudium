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

//! This module implements backwards compatibility for old chunks of the server
//! that still use cache_set() and cache_get()

constant cvs_version = "$Id$";

#ifdef ENABLE_THREADS
  static Thread.Mutex mutex = Thread.Mutex();
# define LOCK() object __key = mutex->lock(1)
#else
# define LOCK() 
#endif

#include <config.h>

inherit "base_server/cachelib";

object cache_manager;
object my_cache;

//! Initiate the cache with a copy of the cache manager for later use
//! 
//! @param cm
//! A Copy of the cache manager, so that we can get our cache when we want it.
void create( object cm ) {
  LOCK();
  cache_manager = cm;
#ifdef CACHE_DEBUG
  write("CACHE: Compatibility now online.\n");
#endif
}

//! Delayed start trigger.
void start_cache() {
  LOCK();
  if ( ! objectp( my_cache ) ) {
    my_cache = cache_manager->get_cache( "DEFAULT" );
    string desc =
      "This is the default cache used by the internals of Caudium, it is used "
      "for such intricacies as storing bytecode compiled versions of modules, "
      "fonts, htaccess information, supports data, etc. This is what you want "
      "to flush if your trying to develop a module and it keeps reloading "
      "with the same version.";
    my_cache->cache_description( desc );
  }
}

//! Compatible expire efun
//!
//! @param in
//! The type of object.
void cache_expire(string in)
{
  start_cache();
  my_cache->flush( sprintf( "^%s://", in ) );
}

//! Compatible retrieve efun
//!
//! @param in
//! The virtual namespace of the object
//! 
//! @param what
//! The name of the object to retrieve
mixed cache_lookup( string in, string what ) {
  start_cache();
  return (what && my_cache->retrieve( sprintf( "%s://%s", in, what ) ))||0;
}

//! Status information
//!
//! @note
//! make this return something relevant.
string status() {
  /*
   * Not implemented, sorry. ***FIXME***
   */
  return cache_manager->status();
}

//! Compatible cache removal efun
//!
//! @param in
//! The virtual namespace of the object
//!
//! @param what
//! The name of the object to remove.
void cache_remove(string in, string what) {
  start_cache();
  my_cache->refresh( sprintf( "%s://%s", in, what ) );
}

//! Compatible cache storage efun
//!
//! @param in
//! The virtual namespace in which to store the object
//!
//! @param what
//! The name of the object to store
//!
//! @param to
//! The object to store
//!
//! @param tm
//! Optional expiry time.
mixed cache_set(string in, string what, mixed to, int|void tm) {
  start_cache();
  if(what)
    my_cache->store( cache_pike_object( to, sprintf( "%s://%s", in, what ), tm ) );
  return to;
}

//! Flush a cache
//!
//! @param in
//! The virtual namespace to remove
void cache_clear(string in) {
  cache_expire( in );
}

//! The method does nothing, it is only here for compatibility with the old
//! class. The original used to cause the cache to expire old objects, the
//! new cache system does this without any external prompting, so we dont
//! need to do it from here.
void cache_clean() {
}
