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

object real_cache;
function get_cache;
string namespace;

private void restart_cache() {
  if ( ! real_cache ) {
    real_cache = get_cache( namespace, 1 );
  }
}

void create( object _real_cache, function _get_cache, string _namespace ) {
  real_cache = _real_cache;
  get_cache = _get_cache;
  namespace = _namespace;
#ifdef CACHE_DEBUG
  write( sprintf( "CLIENT_CACHE: Client cache in namespace %O created.\n", namespace ) );
#endif

}

void set_sizes( int max_object_ram, int max_object_disk ) {
  restart_cache();
  real_cache->set_sizes( max_object_ram, max_object_disk );
}

void set_default_ttl( int default_ttl ) {
  restart_cache();
  real_cache->set_default_ttl( default_ttl );
}

int ram_usage() {
  restart_cache();
  return real_cache->ram_usage();
}

int disk_usage() {
  restart_cache();
  return real_cache->disk_usage();
}

mapping status() {
  restart_cache();
  return real_cache->status();
}

void store( mapping cache_response ) {
  restart_cache();
  real_cache->store( cache_response );
}

void|mapping retrieve( string name, void|function get_callback, void|array cb_args ) {
  restart_cache();
  return real_cache->retrieve( name, get_callback, cb_args );
}

void refresh( string name ) {
  restart_cache();
  real_cache->refresh( name );
}

void free_ram( int nbytes ) {
  restart_cache();
  real_cache->free_ram( nbytes );
}

void free_disk( int nbytes ) {
  restart_cache();
  real_cache->free_disk( nbytes );
}

void flush( void|string regexp ) {
  restart_cache();
  real_cache->flush( regexp );
}

void stop() {
  restart_cache();
  real_cache->stop();
}

void|string cache_description( void|string desc ) {
  restart_cache();
  return real_cache->cache_description( desc );
}
