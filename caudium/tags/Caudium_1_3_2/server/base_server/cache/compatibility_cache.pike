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

// $Id$

#include <config.h>

inherit "caudiumlib";
inherit "cachelib";

object cache_manager;
object my_cache;

void create( object cm ) {
  cache_manager = cm;
#ifdef CACHE_DEBUG
  perror("CACHE: Compatibility now online.\n");
#endif
}

void start_cache() {
  if ( ! objectp( my_cache ) ) {
    my_cache = cache_manager->get_cache( "DEFAULT" );
    my_cache->cache_description( "Cache for the Caudium server's internal needs.\n" );
  }
}

void cache_expire(string in)
{
  start_cache();
  my_cache->flush( sprintf( "^%s://", in ) );
}

mixed cache_lookup( string in, string what ) {
  start_cache();
  return my_cache->retrieve( sprintf( "%s://%s", in, what ) )||0;
}

string status() {
  /*
   * Not implemented, sorry. ***FIXME***
   */
  return cache_manager->status();
}

void cache_remove(string in, string what) {
  start_cache();
  my_cache->refresh( sprintf( "%s://%s", in, what ) );
}

mixed cache_set(string in, string what, mixed to, int|void tm) {
  start_cache();
  my_cache->store( cache_pike_object( to, sprintf( "%s://%s", in, what ), tm ) );
  return to;
}

void cache_clear(string in) {
  cache_expire( in );
}

void cache_clean() {
}
