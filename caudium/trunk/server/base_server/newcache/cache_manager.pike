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

/*
 * cache_manager.pike
 *
 * This class maintains the sizes and 
 */


constant cvs_version = "$id: cache_manager.pike,v 1.0 2001/12/26 18:21:00 james_tyson Exp $";

// This object is part of caudium, which handles how much maximum ram and
// disk that the caches can use in total.
// So, if you want to use a cache in a caudium module somewhere you would
// ask for caudium->cache_manager->get_cache( string namespace )
// cache_manager will keep a record of what caches are running and in
// what namespaces they are. It will share out memory between them if the
// total cache ram usage ever grows bigger than the maximum allowable size.
// It's selection algorhythm is pretty simple, it simply calls
// set_maxsize( int n ) on any caches that are bigger than the average
// size of caches with a new memory limit slightly smaller than the one it
// currently has in order to tell the cache to use less RAM. The cache
// object will then set a callout to free() within itself to some time in
// the not too distant future, thus efectively reducing the total ram usage.
// Actually, now that I think of it, why not just lose the per-cache ram
// limit, and have cache_manager call free() in each cache with an amount
// of ram to free, like telling it to lose weight.

	// You should be able to replicate disk_cache.pike to store data
	// in a SQL server or LDAP database, gdmb or what have you.
	// It should even be relatively simple, and eventually will be
	// controlled by a CIF variable.
	// The whole cache is designed to be highly pluggable.
program dcache = (program)"disk_cache";
program rcache = (program)"ram_cache";
program cache = (program)"cache";
int max_ram_size;
int max_disk_size;
int vigilance;
mapping caches;
string path;

void create( int _max_ram_size, int _max_disk_size, int _vigilance, string _path ) {
	// store the max_ram_size and max_disk_size as properties of
	// cache_manager. Also, create the mapping used to store the caches.
	// set a callout to to watch_size() for calling in the not too
	// distant future - possibly using randomness to decide when to
	// check the total size. Obviously freeing RAM is a costly exercise
	// because most of the data being moved will wind up being written
	// to disk. Probably go with selecting a random number between 1 and
	// 100, and comparing it with the analness percentage - lower analness
	// gives faster performance but sloppier memory usage.
	// Also, probably a good time to pre-create a cache with the namespace
	// "DEFAULT" which is used internally by various things, and save
	// ourselves a shitload of cpu trash during the first page request.
	// vigilance is how vigilant the server is at keeping to the RAM and
	// disk limits that are set (percentage).
        // _path: the path on the filesystem to store caches objects.
  max_ram_size = _max_ram_size;
  max_disk_size = _max_disk_size;
  vigilance = _vigilance;
  path = _path;
  caches = ([ ]);
  create_cache( "DEFAULT" );
  call_out( watch_size, sleepfor() );
}

private void create_cache( string namespace ) {
  int max_object_ram = (int)(max_ram_size * 0.25);
  int max_object_disk = (int)(max_disk_size * 0.25);
  caches += ([ namespace : cache( namespace, path, max_object_ram, max_object_disk, rcache, dcache ) ]);
}

private int sleepfor() {
	// sleepfor() calculates how long to sleep between callouts to
	// watch_size(), alsolute minimum time for a sleep is 30 seconds,
	// providing that vigilance is set to 100% and the last random
	// call returns 0. Maximum is 21 minutes from the last call
	// (vigilance = 0%)
  return random(1200 * ( 1 - ( vigilance / 100 ) ) ) + 30 + random(30);
}

void set_params( int _max_ram_size, int _max_disk_size, int _vigilance ) {
	// Provide the ability to change the size of the caches on the fly
	// from the config interface.
	// Call set_max_ram_size() and set_max_disk_size() on every cache.
  max_ram_size = _max_ram_size;
  max_disk_size = _max_disk_size;
  vigilance = _vigilance;
  foreach( indices( caches ), string namespace ) {
    caches[ namespace ]->set_sizes( max_ram_size, max_disk_size );
  }
}

void watch_size() {
	// sum the total amount of RAM being used by all caches (ram_total), if
	// that is exceeding the maximum amount of ram that we are allowed
	// to use (max_ram_size) then devide the total cache usage by the
	// number of caches that are running (avg_ram_size). Find all caches
	// whose ram_size is greater than avg_ram_size and count them
	// (array big_caches), find the amount of offending ram by subtracting
	// max_ram_size from ram_total (exceed_ram), devide that by the number
	// of big_caches (freethis) and call free( freethis ) on each cache in
	// big_caches. This should be an effective way of managing the amount
	// of ram being used by all the caches without letting a single cache
	// fill it up and not let anything else have any.
	// Once we are sure that everything is finished om the RAM size then
	// repeat the entire process for disk cache.
	// Set another callout to watch_size() using the same randomness rules
	// as decided in create()
  mapping cache_ram_sizes = ([ ]);
  mapping cache_disk_sizes = ([ ]);
  int ram_total, disk_total;
  foreach( indices( caches ), string namespace ) {
    int size = caches[ namespace ]->ram_usage();
    cache_ram_sizes[ namespace ] = size;
    ram_total += size;
  }
  if ( ram_total > max_ram_size ) {
#ifdef DEBUG
  write( "CACHE_MANAGER: Caches exceed maximum allowed memory!\n" );
#endif
	// Go into cleanup mode - we have some caches that are using too much ram.
	// Firstly, locate the average cache size.
    int average_size = ram_total / sizeof( indices( caches ) );
	// Next, find out which caches are bigger than the average size.
    array big_caches = ({ });
    foreach( indices( cache_ram_sizes ), string namespace ) {
      if ( cache_ram_sizes[ namespace ] > average_size ) {
        big_caches += ({ namespace });
      }
    }
	// Now figure out how much we need to free in the caches.
    int must_free = ram_total - max_ram_size;
	// Figure out how much to free in each cache.
    int free_each = must_free / sizeof( big_caches );
	// Call free_ram() on each of the cache objects that have too much
	// RAM usage using the value free_each.
    foreach( big_caches, string namespace ) {
      caches[ namespace ]->free_ram( free_each );
    }
  }
	// Thus concludes memory size management.
	// Now we do it all again, but for disk usage.
  foreach( indices( caches ), string namespace ) {
    int size = caches[ namespace ]->disk_usage();
    cache_disk_sizes[ namespace ] = size;
    disk_total += size;
  }
  if ( disk_total > max_disk_size ) {
    int average_size = disk_total / sizeof( indices( caches ) );
    array big_caches = ({ });
    foreach( indices( cache_disk_sizes ), string namespace ) {
      if ( cache_disk_sizes[ namespace ] > average_size ) {
        big_caches += ({ namespace });
      }
    }
    int must_free = max_disk_size - disk_total;
    int free_each = must_free / sizeof( big_caches );
    foreach( big_caches, string namespace ) {
      caches[ namespace ]->free_disk( free_each );
    }
  }
  call_out( watch_size, sleepfor() );
}

object get_cache( void|string namespace ) {
	// create a cache object using the namespace given and then store
	// it in a mapping and return the object to the caller, thus allowing
	// us to make sure that ram and disk quotas arent exceeded.
        // Also, only call create_cache() if it doesn't already exist - coz
	// if we call create_cache() on a cache that already exists then all
	// it's existing data will effectively be flushed - and possibly
	// corrupted.
  if ( ! namespace ) {
    namespace = "DEFAULT";
  }
  if ( ! caches[ namespace ] ) {
    create_cache( namespace );
  }
  return caches[ namespace ];
}

void destroy() {
  stop();
}

void stop( void|string namespace ) {
  if ( namespace ) {
    if ( caches[ namespace ] ) {
      caches[ namespace ]->stop();
      destruct( caches[ namespace ] );
      m_delete( caches, namespace );
    }
  } else { 
    foreach( indices( caches ), string namespace ) {
      caches[ namespace ]->stop();
      destruct( caches[ namespace ] );
      m_delete( caches, namespace );
    }
  }
}
