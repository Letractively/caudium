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

void cache_expire(string in)
{
  object this_cache = cache_manager->get_cache( in );
  this_cache->flush();
}

mixed cache_lookup( string in, string what ) {
  object this_cache = cache_manager->get_cache( in );
  return this_cache->retrieve( what, 1 )||0;
}

string status() {
  /*
   * Not implemented, sorry. ***FIXME***
   */
  return "";
}

void cache_remove(string in, string what) {
  object this_cache = cache_manager->get_cache( in );
  this_cache->refresh( what );
}

mixed cache_set(string in, string what, mixed to, int|void tm) {
  object this_cache = cache_manager->get_cache( in );
  this_cache->store( cache_pike_object( to, what, tm ) );
  return to;
}

void cache_clear(string in) {
  cache_expire( in );
}

void cache_clean() {
}

void start( object cm )
{
#ifdef CACHE_DEBUG
  perror("CACHE: Now online.\n");
#endif
  cache_manager = cm;
}
