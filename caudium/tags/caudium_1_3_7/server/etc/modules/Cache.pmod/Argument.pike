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
 * The Cache module and the accompanying code is Copyright © 2002 James Tyson.
 * This code is released under the GPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   James Tyson	<jnt@caudium.net>
 *
 */

#define START() if(!objectp(cache))cache=cache_manager->get_cache()

constant cvs_version = "$Id$";

inherit "base_server/cachelib";
inherit "helpers";

// Not sure about this, do we want to cache it forever?
// what happens if gtext wants the arguments and they arent there?
#define DEFAULT_TTL -1

object cache_manager;
object cache;

void create( object _cache_manager) {
  cache_manager = _cache_manager;
}

string store(mapping args) {
  START();
  array b = values(args), a = sort(indices(args),b);
  string data = MIME.encode_base64(encode_value(({a,b})),1);
  string id = get_hash(data);
  cache->store(cache_pike(args,id,DEFAULT_TTL));
  return id;
}

void|mapping lookup(string id, void|string client) {
  START();
  //what happens if it's not there? Argh!
  return cache->retrieve(id);
}
